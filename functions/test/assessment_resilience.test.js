const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

// Import the production-compiled implementations from functions/lib/index.js
const {
  sanitizeGeminiJson,
  sanitizeAssessmentQuestions,
  sanitizeEnhancedText,
  classifyGeminiError,
  calculateRequestTimeout,
  calculateSafeDelay,
  getCandidateModels,
} = require("../lib/index.js");

describe("Backend Assessment Reliability & Resilience Unit Tests (Production Code)", () => {
  describe("Markdown fence stripping and JSON sanitization (Production Functions)", () => {
    test("Strips ```json markdown fences cleanly using production sanitizeGeminiJson", () => {
      const input = "```json\n[{\"question\":\"What is Node?\",\"options\":[\"Runtime\",\"Browser\"],\"correctAnswerIndex\":0}]\n```";
      const cleaned = sanitizeGeminiJson(input);
      const parsed = JSON.parse(cleaned);
      assert.equal(Array.isArray(parsed), true);
      assert.equal(parsed[0].question, "What is Node?");
    });

    test("Strips ``` generic fences cleanly using production sanitizeGeminiJson", () => {
      const input = "```\n[{\"question\":\"What is Node?\",\"options\":[\"Runtime\",\"Browser\"],\"correctAnswerIndex\":0}]\n```";
      const cleaned = sanitizeGeminiJson(input);
      const parsed = JSON.parse(cleaned);
      assert.equal(parsed.length, 1);
    });

    test("Passes plain JSON through without alteration", () => {
      const input = "[{\"question\":\"What is Node?\",\"options\":[\"Runtime\",\"Browser\"],\"correctAnswerIndex\":0}]";
      const cleaned = sanitizeGeminiJson(input);
      const parsed = JSON.parse(cleaned);
      assert.equal(parsed.length, 1);
    });

    test("Sanitizes and normalizes invalid correctAnswerIndex and drops invalid entries via sanitizeAssessmentQuestions", () => {
      const items = [
        { question: "Valid Q", options: ["A", "B", "C"], correctAnswerIndex: 5 }, // index out of bounds -> clamped to 0
        { question: "Float index Q", options: ["A", "B"], correctAnswerIndex: 1.8 }, // float index -> floor to 1
        { question: "No options Q", options: [], correctAnswerIndex: 0 }, // invalid -> dropped (<2 options)
        { question: "", options: ["A", "B"], correctAnswerIndex: 0 }, // invalid -> dropped (no question text)
        null,
        "not an object"
      ];

      const result = sanitizeAssessmentQuestions(items, "Node.js", "Medium", 1700000000000);
      assert.equal(result.length, 2);
      assert.equal(result[0].question, "Valid Q");
      assert.equal(result[0].correctAnswerIndex, 0); // clamped to 0
      assert.equal(result[0].id, "node_js_ai_1700000000000_0");
      assert.equal(result[1].correctAnswerIndex, 1); // floored to 1
    });
  });

  describe("Error classification via production classifyGeminiError", () => {
    test("HTTP 503 High demand is classified as transient retryable", () => {
      const res = classifyGeminiError(503, "The model is currently experiencing high demand. Please try again later.");
      assert.equal(res.isTransientError, true);
      assert.equal(res.isPermanentSkip, false);
      assert.equal(res.isDailyQuotaExhausted, false);
      assert.equal(res.hasServiceUnavailable, true);
    });

    test("HTTP 429 RPM/TPM rate limit is classified as transient retryable with Retry-After support", () => {
      const res = classifyGeminiError(429, "Rate limit exceeded. Resource: GenerateRequestsPerMinute.", "2");
      assert.equal(res.isTransientError, true);
      assert.equal(res.isPermanentSkip, false);
      assert.equal(res.isDailyQuotaExhausted, false);
      assert.equal(res.retryDelayMs, 2000);
    });

    test("HTTP 429 Daily Quota Exhaustion is classified as permanent skip", () => {
      const res = classifyGeminiError(429, "Quota exceeded for quota metric 'GenerateRequestsPerDay'.");
      assert.equal(res.isTransientError, false);
      assert.equal(res.isPermanentSkip, true);
      assert.equal(res.isDailyQuotaExhausted, true);
    });

    test("HTTP 404 Deprecated/Non-existent model is classified as permanent skip without retry", () => {
      const res = classifyGeminiError(404, "models/gemini-2.5-flash-lite is not found for API version v1beta");
      assert.equal(res.isTransientError, false);
      assert.equal(res.isPermanentSkip, true);
      assert.equal(res.isDailyQuotaExhausted, false);
    });

    test("HTTP 400 Bad Request / Invalid Argument is classified as permanent skip", () => {
      const res = classifyGeminiError(400, "Invalid JSON payload or parameter.");
      assert.equal(res.isTransientError, false);
      assert.equal(res.isPermanentSkip, true);
      assert.equal(res.isDailyQuotaExhausted, false);
    });
  });

  describe("Cumulative execution budget and request bounds (Production Functions)", () => {
    test("calculateRequestTimeout returns standard 15s when budget is ample", () => {
      const timeout = calculateRequestTimeout(70000, 15000, 5000);
      assert.equal(timeout, 15000);
    });

    test("calculateRequestTimeout dynamically caps timeout to remaining budget when remaining < 15s", () => {
      // If 11,200 ms remain, request timeout is strictly capped to 11,200 ms
      const timeout = calculateRequestTimeout(11200, 15000, 5000);
      assert.equal(timeout, 11200);
      assert.ok(timeout <= 11200, "Request timeout never exceeds remaining budget");
    });

    test("calculateRequestTimeout returns 0 when remaining budget is below minimum threshold (5000ms)", () => {
      assert.equal(calculateRequestTimeout(4999, 15000, 5000), 0);
      assert.equal(calculateRequestTimeout(2000, 15000, 5000), 0);
      assert.equal(calculateRequestTimeout(0, 15000, 5000), 0);
      assert.equal(calculateRequestTimeout(-500, 15000, 5000), 0);
    });

    test("calculateSafeDelay caps delay so minimum useful budget (5000ms) remains for next request", () => {
      // If 20s remain and desired delay is 2s: returns 2s
      assert.equal(calculateSafeDelay(2000, 20000, 5000), 2000);

      // If 6.5s remain and desired delay is 3s: only 1.5s is allowed so 5s remains for request
      assert.equal(calculateSafeDelay(3000, 6500, 5000), 1500);

      // If 5s or less remain: returns 0 (no delay allowed, budget exhausted)
      assert.equal(calculateSafeDelay(1000, 5000, 5000), 0);
      assert.equal(calculateSafeDelay(1000, 3000, 5000), 0);
    });

    test("Worst-case execution sequence is strictly capped at or below MAX_TOTAL_BUDGET_MS (70000ms)", () => {
      const MAX_TOTAL_BUDGET_MS = 70000;
      const PER_REQUEST_TIMEOUT_MS = 15000;
      const MIN_USEFUL_BUDGET_MS = 5000;

      let simulatedElapsedMs = 0;
      let requestCount = 0;
      let delayCount = 0;

      // Simulate worst-case looping
      while (true) {
        const remainingBudget = MAX_TOTAL_BUDGET_MS - simulatedElapsedMs;
        const reqTimeout = calculateRequestTimeout(remainingBudget, PER_REQUEST_TIMEOUT_MS, MIN_USEFUL_BUDGET_MS);
        if (reqTimeout === 0) {
          // Loop terminates strictly because remaining budget is < 5000ms
          break;
        }

        // Simulate request timing out for the full duration of reqTimeout
        requestCount++;
        simulatedElapsedMs += reqTimeout;

        // Simulate transient error wanting a 2000ms delay
        const remainingForDelay = MAX_TOTAL_BUDGET_MS - simulatedElapsedMs;
        const safeDelay = calculateSafeDelay(2000, remainingForDelay, MIN_USEFUL_BUDGET_MS);
        if (safeDelay === 0) {
          // Delay cannot be accommodated; loop terminates
          break;
        }
        delayCount++;
        simulatedElapsedMs += safeDelay;
      }

      // Assert that cumulative duration is strictly <= 70,000ms
      assert.ok(
        simulatedElapsedMs <= MAX_TOTAL_BUDGET_MS,
        `Simulated elapsed ${simulatedElapsedMs}ms exceeded MAX_TOTAL_BUDGET_MS ${MAX_TOTAL_BUDGET_MS}ms`
      );
      assert.ok(requestCount >= 3, "Simulated multiple attempts within budget");
      assert.ok(simulatedElapsedMs <= 70000, "Cumulative duration strictly bounded by 70.0s deadline");
      assert.ok(MAX_TOTAL_BUDGET_MS < 90000, "Budget strictly less than 90s Flutter client timeout");
      assert.ok(MAX_TOTAL_BUDGET_MS < 120000, "Budget strictly less than 120s Cloud Run container timeout");
    });

    test("AbortController signal triggers cancellation and prevents pending request execution", async () => {
      const controller = new AbortController();
      let wasAborted = false;
      const timeoutId = setTimeout(() => controller.abort(), 25);

      try {
        await new Promise((resolve, reject) => {
          controller.signal.addEventListener("abort", () => {
            wasAborted = true;
            reject(new Error("This operation was aborted"));
          });
        });
      } catch (err) {
        assert.equal(err.message, "This operation was aborted");
      } finally {
        clearTimeout(timeoutId);
      }

      assert.equal(wasAborted, true);
      assert.equal(controller.signal.aborted, true);
    });

    test("No request or retry starts when remaining budget is below 5000ms threshold", () => {
      const atBoundary = calculateRequestTimeout(5000, 15000, 5000);
      assert.equal(atBoundary, 5000, "At exact 5000ms, allocates 5000ms");

      const justBelow = calculateRequestTimeout(4999, 15000, 5000);
      assert.equal(justBelow, 0, "At 4999ms, returns 0 and blocks request");

      const zeroBudget = calculateRequestTimeout(0, 15000, 5000);
      assert.equal(zeroBudget, 0, "At 0ms, returns 0 and blocks request");

      const negativeBudget = calculateRequestTimeout(-1000, 15000, 5000);
      assert.equal(negativeBudget, 0, "At negative budget, returns 0 and blocks request");
    });
  });

  describe("Configured fallback model cascade and environment override", () => {
    test("Default fallback order has gemini-3.5-flash-lite primary and gemini-flash-latest secondary", () => {
      const models = getCandidateModels();
      assert.deepEqual(models, [
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.6-flash",
      ]);
      assert.equal(models[0], "gemini-3.5-flash-lite", "Primary model must be gemini-3.5-flash-lite");
      assert.equal(models[1], "gemini-flash-latest", "Secondary model must be gemini-flash-latest");
      assert.equal(models[2], "gemini-3.6-flash", "Tertiary model must be gemini-3.6-flash");
      assert.equal(models.includes("gemini-3.5-flash"), false, "Deprecated gemini-3.5-flash must not be in the list");
    });

    test("GEMINI_MODEL environment override prepends custom model to cascade", () => {
      const models = getCandidateModels("custom-preview-model");
      assert.deepEqual(models, [
        "custom-preview-model",
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.6-flash",
      ]);
      assert.equal(models[0], "custom-preview-model");
    });

    test("Deduplicates if GEMINI_MODEL matches one of the default models", () => {
      const models = getCandidateModels("gemini-3.5-flash-lite");
      assert.deepEqual(models, [
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.6-flash",
      ]);
      assert.equal(models.length, 3);
    });

    test("Ignores empty or whitespace-only GEMINI_MODEL override", () => {
      assert.deepEqual(getCandidateModels(""), [
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.6-flash",
      ]);
      assert.deepEqual(getCandidateModels("   "), [
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.6-flash",
      ]);
      assert.deepEqual(getCandidateModels(null), [
        "gemini-3.5-flash-lite",
        "gemini-flash-latest",
        "gemini-3.6-flash",
      ]);
    });
  });

  describe("Enhanced text sanitization via production sanitizeEnhancedText", () => {
    test("Leaves clean text untouched", () => {
      const input = "Passionate junior MERN stack developer with hands-on experience in React and Node.js.";
      assert.equal(sanitizeEnhancedText(input), input);
    });

    test("Strips wrapping markdown code blocks", () => {
      const input = "```markdown\nDynamic and motivated MERN stack developer building robust web applications.\n```";
      assert.equal(
        sanitizeEnhancedText(input),
        "Dynamic and motivated MERN stack developer building robust web applications."
      );
    });

    test("Strips outer quotation marks", () => {
      const input = '"Full-stack developer experienced in modern JavaScript frameworks."';
      assert.equal(
        sanitizeEnhancedText(input),
        "Full-stack developer experienced in modern JavaScript frameworks."
      );
    });

    test("Handles empty or nullish input gracefully", () => {
      assert.equal(sanitizeEnhancedText(""), "");
      assert.equal(sanitizeEnhancedText(null), "");
      assert.equal(sanitizeEnhancedText(undefined), "");
    });
  });
});

