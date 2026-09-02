"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRelatedSkills = exports.generateAssessmentQuestions = exports.enhanceText = exports.bulkPostJobs = exports.generateJobDescription = exports.onMessageCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
exports.onMessageCreated = (0, firestore_1.onDocumentCreated)("chats/{chatId}/messages/{messageId}", async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const snap = event.data;
    if (!snap)
        return;
    const defaultIcon = "https://cdn-icons-png.flaticon.com/512/149/149071.png";
    const newMessage = snap.data();
    const chatId = event.params.chatId;
    const senderId = newMessage.senderId;
    // content might be encrypted, but could be useful if decrypted later. Ignoring for now.
    // const content = newMessage.content;
    try {
        // 1. Get Chat details to find the recipient
        const chatDoc = await db.collection("chats").doc(chatId).get();
        if (!chatDoc.exists) {
            console.log("Chat document not found:", chatId);
            return null;
        }
        const chatData = chatDoc.data();
        // Assuming chat string stores both UIDs or has candidateId and recruiterId
        const candidateId = chatData.candidateId;
        const recruiterId = chatData.recruiterId;
        if (!candidateId || !recruiterId) {
            console.log("Missing participant IDs in chat");
            return null;
        }
        const isSenderRecruiter = senderId === recruiterId;
        const recipientId = isSenderRecruiter ? candidateId : recruiterId;
        // 2. Get sender profile for name and image
        let senderName = "User";
        let senderImageUrl = defaultIcon;
        let jobTitle = "Job";
        if (chatData.jobId) {
            try {
                const jobDoc = await db.collection("jobs").doc(chatData.jobId).get();
                if (jobDoc.exists) {
                    jobTitle = ((_a = jobDoc.data()) === null || _a === void 0 ? void 0 : _a.roleName) || "Job";
                }
            }
            catch (e) { }
        }
        if (isSenderRecruiter) {
            const recruiterDoc = await db.collection("recruiters").doc(senderId).get();
            if (recruiterDoc.exists) {
                senderName = ((_b = recruiterDoc.data()) === null || _b === void 0 ? void 0 : _b.fullName) || "Recruiter";
                senderImageUrl = ((_c = recruiterDoc.data()) === null || _c === void 0 ? void 0 : _c.photoUrl) || defaultIcon;
            }
        }
        else {
            const candidateDoc = await db.collection("candidates").doc(senderId).get();
            if (candidateDoc.exists) {
                senderName = ((_d = candidateDoc.data()) === null || _d === void 0 ? void 0 : _d.firstName)
                    ? `${(_e = candidateDoc.data()) === null || _e === void 0 ? void 0 : _e.firstName} ${(_f = candidateDoc.data()) === null || _f === void 0 ? void 0 : _f.lastName}`.trim()
                    : "Candidate";
                senderImageUrl = ((_g = candidateDoc.data()) === null || _g === void 0 ? void 0 : _g.photoUrl) || defaultIcon;
            }
        }
        // 3. Get recipient FCM Token
        let fcmToken = null;
        if (isSenderRecruiter) {
            // Recipient is candidate
            const candidateDoc = await db.collection("candidates").doc(recipientId).get();
            fcmToken = (_h = candidateDoc.data()) === null || _h === void 0 ? void 0 : _h.fcmToken;
        }
        else {
            // Recipient is recruiter
            const recruiterDoc = await db.collection("recruiters").doc(recipientId).get();
            fcmToken = (_j = recruiterDoc.data()) === null || _j === void 0 ? void 0 : _j.fcmToken;
        }
        // 4. Also write to notification_recruter / notification_candidate if needed
        // (The Flutter app is already listening to these collections)
        if (isSenderRecruiter) {
            // Create for candidate
            await db.collection("notification_candidate").add({
                userId: recipientId,
                type: 'message',
                title: `New Message from ${senderName}`,
                content: 'You have received a new message.',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                isRead: false,
                payloadId: chatId,
                jobId: chatData.jobId,
                candidateId: candidateId,
                recruiterId: recruiterId,
            });
        }
        else {
            // Create for recruiter
            await db.collection("notification_recruter").add({
                recruiterId: recipientId,
                type: 'message',
                title: `New Message from ${senderName}`,
                content: 'You have received a new message.',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                isRead: false,
                payloadId: chatId,
                jobId: chatData.jobId,
                candidateId: candidateId,
                candidateName: senderName,
                candidateImageUrl: senderImageUrl,
                jobTitle: jobTitle
            });
        }
        if (!fcmToken) {
            console.log(`No FCM token found for user ${recipientId}`);
            return null;
        }
        // 5. Send FCM Push Notification
        const payload = {
            notification: {
                title: `New Message from ${senderName}`,
                body: 'You have received a new message.',
                image: senderImageUrl,
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                type: "chat",
                chatId: chatId,
                senderName: senderName,
                otherUserId: senderId,
            },
            token: fcmToken,
        };
        await admin.messaging().send(payload);
        console.log(`Successfully sent notification to ${recipientId}`);
    }
    catch (error) {
        console.error("Error processing notification:", error);
    }
    return null;
});
exports.generateJobDescription = (0, https_1.onCall)({ secrets: ["GEMINI_API_KEY"] }, async (request) => {
    var _a, _b, _c, _d, _e;
    // 1. Authentication Check
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = request.auth.uid;
    try {
        // 2. Authorization Check (Recruiter only)
        const recruiterDoc = await db.collection("recruiters").doc(userId).get();
        if (!recruiterDoc.exists) {
            throw new https_1.HttpsError("permission-denied", "Only authenticated recruiters are authorized to generate job descriptions.");
        }
        // 3. Payload and Input Validation
        const data = request.data;
        if (!data) {
            throw new https_1.HttpsError("invalid-argument", "Missing request payload.");
        }
        const { role, skills } = data;
        if (!role || typeof role !== "string" || role.trim().length === 0) {
            throw new https_1.HttpsError("invalid-argument", "Role is required and must be a non-empty string.");
        }
        if (role.length > 100) {
            throw new https_1.HttpsError("invalid-argument", "Job role is too long (maximum 100 characters).");
        }
        if (!skills || !Array.isArray(skills)) {
            throw new https_1.HttpsError("invalid-argument", "Skills must be provided as a list.");
        }
        if (skills.length > 20) {
            throw new https_1.HttpsError("invalid-argument", "Too many skills provided (maximum 20).");
        }
        for (let i = 0; i < skills.length; i++) {
            const skill = skills[i];
            if (typeof skill !== "string") {
                throw new https_1.HttpsError("invalid-argument", `Skill at index ${i} must be a string.`);
            }
            if (skill.trim().length === 0) {
                throw new https_1.HttpsError("invalid-argument", `Skill at index ${i} cannot be empty.`);
            }
            if (skill.length > 50) {
                throw new https_1.HttpsError("invalid-argument", `Skill "${skill}" is too long (maximum 50 characters).`);
            }
        }
        // 4. Secure API Key Retrieval
        const apiKey = (process.env.GEMINI_API_KEY || "").trim();
        if (!apiKey) {
            console.error("GEMINI_API_KEY secret is not configured on the backend.");
            throw new https_1.HttpsError("failed-precondition", "AI service is currently misconfigured.");
        }
        // 5. Configurable Model Name (Default to gemini-3.6-flash)
        const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";
        const prompt = `Generate a job description for the role of "${role.trim()}".
Key skills involved: ${skills.map(s => s.trim()).join(', ')}.

Please provide the output in the following JSON format ONLY, without any markdown formatting block:
{
  "description": "A compelling 3-4 sentence job description.",
  "responsibilities": ["Responsibility 1", "Responsibility 2", "Responsibility 3", "Responsibility 4", "Responsibility 5", "Responsibility 6"],
  "requirements": ["Requirement 1", "Requirement 2", "Requirement 3", "Requirement 4", "Requirement 5", "Requirement 6"]
}
Make the tone professional and exciting.`;
        // 6. Invoke Gemini API via standard Fetch
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                contents: [
                    {
                        parts: [
                            {
                                text: prompt,
                            },
                        ],
                    },
                ],
                generationConfig: {
                    responseMimeType: "application/json",
                },
            }),
        });
        if (!response.ok) {
            const errText = await response.text().catch(() => "");
            console.error(`Gemini API returned status ${response.status}: ${errText}`);
            throw new https_1.HttpsError("internal", "Failed to generate job description from AI service.");
        }
        const responseData = await response.json();
        const responseText = (_e = (_d = (_c = (_b = (_a = responseData === null || responseData === void 0 ? void 0 : responseData.candidates) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.content) === null || _c === void 0 ? void 0 : _c.parts) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.text;
        if (!responseText || typeof responseText !== "string") {
            console.error("Gemini API response did not contain text content:", JSON.stringify(responseData));
            throw new https_1.HttpsError("internal", "Received invalid output format from AI service.");
        }
        // 7. Parse and Validate Response format
        let cleanJson = responseText.trim();
        if (cleanJson.startsWith("```")) {
            cleanJson = cleanJson
                .replace(/^```json\s*/i, "")
                .replace(/^```\s*/, "")
                .replace(/```$/, "")
                .trim();
        }
        let parsedData;
        try {
            parsedData = JSON.parse(cleanJson);
        }
        catch (e) {
            console.error("Failed to parse Gemini response as JSON. Raw text:", responseText, "Error:", e);
            throw new https_1.HttpsError("internal", "AI generated a malformed response format. Please try again.");
        }
        const description = parsedData.description;
        const responsibilities = parsedData.responsibilities;
        const requirements = parsedData.requirements;
        if (typeof description !== "string" || !description.trim()) {
            console.error("Parsed response missing description field:", parsedData);
            throw new https_1.HttpsError("internal", "AI description was empty or malformed.");
        }
        if (!Array.isArray(responsibilities)) {
            console.error("Parsed response responsibilities field is not an array:", parsedData);
            throw new https_1.HttpsError("internal", "AI responsibilities were empty or malformed.");
        }
        if (!Array.isArray(requirements)) {
            console.error("Parsed response requirements field is not an array:", parsedData);
            throw new https_1.HttpsError("internal", "AI requirements were empty or malformed.");
        }
        return {
            description: description.trim(),
            responsibilities: responsibilities.map((r) => String(r).trim()).filter(Boolean),
            requirements: requirements.map((r) => String(r).trim()).filter(Boolean),
        };
    }
    catch (error) {
        // Avoid leaking internal errors (except HttpsError which is intentional)
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        console.error("Unhandled error in generateJobDescription:", error);
        throw new https_1.HttpsError("internal", "An error occurred while generating the job description.");
    }
});
exports.bulkPostJobs = (0, https_1.onCall)(async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    // 1. Authentication Check
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = request.auth.uid;
    const { jobs } = request.data;
    if (!jobs || !Array.isArray(jobs)) {
        throw new https_1.HttpsError("invalid-argument", "Jobs list must be provided as an array.");
    }
    try {
        // 2. Role check in users collection
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists || ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== "recruiter") {
            throw new https_1.HttpsError("permission-denied", "Unauthorized. Only recruiters can perform this action.");
        }
        // 3. Fetch recruiter profile and verify subscription
        const recruiterDoc = await db.collection("recruiters").doc(userId).get();
        if (!recruiterDoc.exists) {
            throw new https_1.HttpsError("permission-denied", "Recruiter profile details not found.");
        }
        const recruiterData = recruiterDoc.data() || {};
        const isSubscribed = recruiterData.isSubscribed || false;
        const companyId = recruiterData.companyId || "";
        if (!isSubscribed) {
            throw new https_1.HttpsError("permission-denied", "Your account is not subscribed. Bulk job posting is disabled.");
        }
        if (!companyId) {
            throw new https_1.HttpsError("failed-precondition", "Recruiter is not linked to any company profile.");
        }
        // 4. Fetch company profile to retrieve name & logo
        const companyDoc = await db.collection("companies").doc(companyId).get();
        let companyName = "";
        let companyLogoUrl = "";
        if (companyDoc.exists) {
            const companyData = companyDoc.data() || {};
            companyName = companyData.companyName || "";
            companyLogoUrl = companyData.logoUrl || companyData.companyLogoUrl || "";
        }
        // 5. Generate and batch write jobs
        const postedAt = admin.firestore.Timestamp.now();
        const expiresAt = admin.firestore.Timestamp.fromDate(new Date(postedAt.toDate().getTime() + 30 * 24 * 60 * 60 * 1000));
        const batch = db.batch();
        let count = 0;
        for (const job of jobs) {
            const jobId = db.collection("jobs").doc().id;
            const jobDocData = {
                jobId: jobId,
                companyId: companyId,
                recruiterId: userId,
                roleId: "custom",
                roleName: job.roleName || "",
                designationId: "custom",
                designationName: job.roleName || "",
                experienceLevel: job.experienceLevel || "Fresher",
                employmentType: job.employmentType || "Full-Time",
                workMode: job.workMode || "Onsite",
                jobLocation: {
                    city: ((_b = job.jobLocation) === null || _b === void 0 ? void 0 : _b.city) || "",
                    state: ((_c = job.jobLocation) === null || _c === void 0 ? void 0 : _c.state) || "",
                    country: ((_d = job.jobLocation) === null || _d === void 0 ? void 0 : _d.country) || "",
                },
                vacancies: parseInt(job.vacancies) || 1,
                officeCount: parseInt(job.officeCount) || 1,
                experienceRequired: {
                    minYears: parseInt((_e = job.experienceRequired) === null || _e === void 0 ? void 0 : _e.minYears) || 0,
                    maxYears: parseInt((_f = job.experienceRequired) === null || _f === void 0 ? void 0 : _f.maxYears) || 0,
                },
                salary: {
                    min: parseFloat((_g = job.salary) === null || _g === void 0 ? void 0 : _g.min) || 0.0,
                    max: parseFloat((_h = job.salary) === null || _h === void 0 ? void 0 : _h.max) || 0.0,
                    currency: ((_j = job.salary) === null || _j === void 0 ? void 0 : _j.currency) || "INR",
                    type: ((_k = job.salary) === null || _k === void 0 ? void 0 : _k.type) || "CTC",
                },
                skillsRequired: Array.isArray(job.skillsRequired) ? job.skillsRequired : [],
                mustHaveSkills: [],
                niceToHaveSkills: [],
                jobDescription: job.jobDescription || "",
                responsibilities: Array.isArray(job.responsibilities) ? job.responsibilities : [],
                requirements: Array.isArray(job.requirements) ? job.requirements : [],
                interviewProcess: [],
                extraQuestions: [],
                status: "active",
                visibility: "public",
                postedAt: postedAt,
                expiresAt: expiresAt,
                companyName: companyName,
                companyLogoUrl: companyLogoUrl,
            };
            const jobRef = db.collection("jobs").doc(jobId);
            batch.set(jobRef, jobDocData);
            count++;
        }
        if (count > 0) {
            await batch.commit();
        }
        return {
            success: true,
            successCount: count,
            message: "Successfully created job posts.",
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        console.error("Unhandled error in bulkPostJobs:", error);
        throw new https_1.HttpsError("internal", `An error occurred while bulk posting: ${error.message}`);
    }
});
exports.enhanceText = (0, https_1.onCall)({ secrets: ["GEMINI_API_KEY"], region: "us-central1" }, async (request) => {
    var _a, _b, _c, _d, _e;
    // 1. Authentication Check
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = request.auth.uid;
    try {
        // 2. Authorization Check (Candidate verification)
        const candidateDoc = await db.collection("candidates").doc(userId).get();
        if (!candidateDoc.exists) {
            throw new https_1.HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
        }
        // 3. Payload and Input Validation
        const data = request.data;
        if (!data) {
            throw new https_1.HttpsError("invalid-argument", "Missing request payload.");
        }
        const { text, type, context } = data;
        if (!text || typeof text !== "string" || text.trim().length === 0) {
            throw new https_1.HttpsError("invalid-argument", "Text is required and must be a non-empty string.");
        }
        if (text.length > 4000) {
            throw new https_1.HttpsError("invalid-argument", "Input text is too long (maximum 4000 characters).");
        }
        const title = (context === null || context === void 0 ? void 0 : context.title) && typeof context.title === "string" ? context.title.slice(0, 200).trim() : "";
        const company = (context === null || context === void 0 ? void 0 : context.company) && typeof context.company === "string" ? context.company.slice(0, 200).trim() : "";
        const role = (context === null || context === void 0 ? void 0 : context.role) && typeof context.role === "string" ? context.role.slice(0, 200).trim() : "";
        // 4. Secure API Key Retrieval
        const apiKey = (process.env.GEMINI_API_KEY || "").trim();
        if (!apiKey) {
            console.error("GEMINI_API_KEY secret is not configured on the backend.");
            throw new https_1.HttpsError("failed-precondition", "AI service is currently misconfigured.");
        }
        // 5. Model Selection
        const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";
        // 6. Build Prompt
        let prompt = "";
        if (type === "summary") {
            prompt = `Enhance this professional summary/bio for a candidate job profile. Headline: "${title}". Current Description: "${text.trim()}". Make it compelling, professional, and highlight key strengths. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
        }
        else if (type === "experience") {
            prompt = `Enhance this job description for a candidate resume. Job Title: "${title}", Company: "${company}". Current Description: "${text.trim()}". Make it professional, focusing on achievements and responsibilities. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
        }
        else if (type === "project") {
            prompt = `Enhance this project description for a candidate portfolio. Title: "${title}", Role: "${role}". Current Description: "${text.trim()}". Make it professional, highlighting technical challenges and outcomes. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
        }
        else {
            prompt = `Enhance the following professional description for a resume/portfolio profile. Text: "${text.trim()}". Make it concise, professional, and impactful. Return ONLY the enhanced text without markdown blocks, commentary, or quotes.`;
        }
        // 7. Invoke Gemini REST API
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                contents: [
                    {
                        parts: [
                            {
                                text: prompt,
                            },
                        ],
                    },
                ],
                generationConfig: {
                    temperature: 0.7,
                },
            }),
        });
        if (!response.ok) {
            const errText = await response.text().catch(() => "");
            console.error(`Gemini API returned status ${response.status}: ${errText}`);
            throw new https_1.HttpsError("internal", "Failed to generate enhanced text from AI service.");
        }
        const responseData = await response.json();
        const responseText = (_e = (_d = (_c = (_b = (_a = responseData === null || responseData === void 0 ? void 0 : responseData.candidates) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.content) === null || _c === void 0 ? void 0 : _c.parts) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.text;
        if (!responseText || typeof responseText !== "string") {
            console.error("Gemini API response did not contain text content:", JSON.stringify(responseData));
            throw new https_1.HttpsError("internal", "Received invalid output from AI service.");
        }
        let enhancedText = responseText.trim();
        if (enhancedText.startsWith("```")) {
            enhancedText = enhancedText
                .replace(/^```[a-zA-Z]*\s*/, "")
                .replace(/```$/, "")
                .trim();
        }
        if (enhancedText.startsWith('"') && enhancedText.endsWith('"') && enhancedText.length > 2) {
            enhancedText = enhancedText.slice(1, -1).trim();
        }
        return {
            enhancedText,
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        console.error("Unhandled error in enhanceText:", error);
        throw new https_1.HttpsError("internal", "An error occurred while enhancing text.");
    }
});
exports.generateAssessmentQuestions = (0, https_1.onCall)({ secrets: ["GEMINI_API_KEY"], region: "us-central1" }, async (request) => {
    var _a, _b, _c, _d, _e;
    // 1. Authentication Check
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = request.auth.uid;
    try {
        // 2. Authorization Check (Candidate verification)
        const candidateDoc = await db.collection("candidates").doc(userId).get();
        if (!candidateDoc.exists) {
            throw new https_1.HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
        }
        // 3. Payload and Input Validation
        const data = request.data;
        if (!data) {
            throw new https_1.HttpsError("invalid-argument", "Missing request payload.");
        }
        const { skill, difficulty = "Medium", count = 15 } = data;
        if (!skill || typeof skill !== "string" || skill.trim().length === 0) {
            throw new https_1.HttpsError("invalid-argument", "Skill is required and must be a non-empty string.");
        }
        if (skill.length > 100) {
            throw new https_1.HttpsError("invalid-argument", "Skill name is too long (maximum 100 characters).");
        }
        const validDifficulties = ["Easy", "Medium", "Hard"];
        const validatedDifficulty = validDifficulties.includes(difficulty) ? difficulty : "Medium";
        const questionCount = typeof count === "number" && count >= 1 && count <= 30 ? Math.floor(count) : 15;
        // 4. Secure API Key Retrieval
        const apiKey = (process.env.GEMINI_API_KEY || "").trim();
        if (!apiKey) {
            console.error("GEMINI_API_KEY secret is not configured on the backend.");
            throw new https_1.HttpsError("failed-precondition", "AI service is currently misconfigured.");
        }
        // 5. Model Selection
        const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";
        const prompt = `Generate ${questionCount} multiple-choice questions for a "${skill.trim()}" assessment.
Difficulty level: ${validatedDifficulty}.

The output must be a valid JSON array of objects.
Each object must have the following structure:
{
  "question": "The question text",
  "options": ["Option A", "Option B", "Option C", "Option D"],
  "correctAnswerIndex": 0
}

Ensure the questions are relevant to ${skill.trim()} and match the ${validatedDifficulty} difficulty.
"options" must have exactly 4 strings.
"correctAnswerIndex" must be an integer from 0 to 3 indicating the correct option.
Do not include any markdown formatting like \`\`\`json ... \`\`\`, just the raw JSON array.`;
        // 6. Invoke Gemini REST API
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                contents: [
                    {
                        parts: [
                            {
                                text: prompt,
                            },
                        ],
                    },
                ],
                generationConfig: {
                    temperature: 0.7,
                    responseMimeType: "application/json",
                },
            }),
        });
        if (!response.ok) {
            const errText = await response.text().catch(() => "");
            console.error(`Gemini API returned status ${response.status}: ${errText}`);
            throw new https_1.HttpsError("internal", "Failed to generate assessment questions from AI service.");
        }
        const responseData = await response.json();
        const responseText = (_e = (_d = (_c = (_b = (_a = responseData === null || responseData === void 0 ? void 0 : responseData.candidates) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.content) === null || _c === void 0 ? void 0 : _c.parts) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.text;
        if (!responseText || typeof responseText !== "string") {
            console.error("Gemini API response did not contain text content:", JSON.stringify(responseData));
            throw new https_1.HttpsError("internal", "Received invalid output format from AI service.");
        }
        // 7. Parse and Validate Response format
        let cleanJson = responseText.trim();
        if (cleanJson.startsWith("```")) {
            cleanJson = cleanJson
                .replace(/^```json\s*/i, "")
                .replace(/^```\s*/, "")
                .replace(/```$/, "")
                .trim();
        }
        let parsedList;
        try {
            parsedList = JSON.parse(cleanJson);
        }
        catch (e) {
            console.error("Failed to parse Gemini response as JSON. Raw text:", responseText, "Error:", e);
            throw new https_1.HttpsError("internal", "AI generated a malformed response format. Please try again.");
        }
        if (!Array.isArray(parsedList) || parsedList.length === 0) {
            console.error("Parsed response is not a non-empty array:", parsedList);
            throw new https_1.HttpsError("internal", "AI failed to generate valid assessment questions.");
        }
        const now = Date.now();
        const sanitizedQuestions = [];
        for (let i = 0; i < parsedList.length; i++) {
            const item = parsedList[i];
            if (!item || typeof item !== "object")
                continue;
            const questionText = typeof item.question === "string" ? item.question.trim() : "";
            const options = Array.isArray(item.options) ? item.options.map((opt) => String(opt).trim()).filter(Boolean) : [];
            let correctIndex = typeof item.correctAnswerIndex === "number" ? Math.floor(item.correctAnswerIndex) : 0;
            if (!questionText || options.length < 2)
                continue;
            if (correctIndex < 0 || correctIndex >= options.length)
                correctIndex = 0;
            sanitizedQuestions.push({
                id: `${skill.toLowerCase().replace(/[^a-z0-9]/g, "_")}_ai_${now}_${i}`,
                question: questionText,
                options: options,
                correctAnswerIndex: correctIndex,
                skill: skill.trim(),
                difficulty: validatedDifficulty,
            });
        }
        if (sanitizedQuestions.length === 0) {
            throw new https_1.HttpsError("internal", "AI generated zero valid questions.");
        }
        return {
            questions: sanitizedQuestions.slice(0, questionCount),
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        console.error("Unhandled error in generateAssessmentQuestions:", error);
        throw new https_1.HttpsError("internal", "An error occurred while generating assessment questions.");
    }
});
exports.getRelatedSkills = (0, https_1.onCall)({ secrets: ["GEMINI_API_KEY"], region: "us-central1" }, async (request) => {
    var _a, _b, _c, _d, _e;
    // 1. Authentication Check
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = request.auth.uid;
    try {
        // 2. Authorization Check (Candidate verification)
        const candidateDoc = await db.collection("candidates").doc(userId).get();
        if (!candidateDoc.exists) {
            throw new https_1.HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
        }
        // 3. Payload and Input Validation
        const data = request.data;
        if (!data) {
            throw new https_1.HttpsError("invalid-argument", "Missing request payload.");
        }
        const { currentSkills } = data;
        if (!currentSkills || !Array.isArray(currentSkills) || currentSkills.length === 0) {
            return { relatedSkills: [] };
        }
        const cleanedSkills = currentSkills
            .filter((s) => typeof s === "string" && s.trim().length > 0)
            .map((s) => s.trim())
            .slice(0, 50);
        if (cleanedSkills.length === 0) {
            return { relatedSkills: [] };
        }
        // 4. Secure API Key Retrieval
        const apiKey = (process.env.GEMINI_API_KEY || "").trim();
        if (!apiKey) {
            console.error("GEMINI_API_KEY secret is not configured on the backend.");
            throw new https_1.HttpsError("failed-precondition", "AI service is currently misconfigured.");
        }
        // 5. Model Selection
        const model = process.env.GEMINI_MODEL || "gemini-3.6-flash";
        const prompt = `Given the following list of technical skills: ${cleanedSkills.join(", ")}.
Suggest 5 related technical skills that this candidate would benefit from learning or might already know.

The output must be a valid JSON array of strings.
Example: ["Skill A", "Skill B", "Skill C"]
Do not include any markdown formatting.`;
        // 6. Invoke Gemini REST API
        const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                contents: [
                    {
                        parts: [
                            {
                                text: prompt,
                            },
                        ],
                    },
                ],
                generationConfig: {
                    temperature: 0.7,
                    responseMimeType: "application/json",
                },
            }),
        });
        if (!response.ok) {
            const errText = await response.text().catch(() => "");
            console.error(`Gemini API returned status ${response.status}: ${errText}`);
            return { relatedSkills: [] };
        }
        const responseData = await response.json();
        const responseText = (_e = (_d = (_c = (_b = (_a = responseData === null || responseData === void 0 ? void 0 : responseData.candidates) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.content) === null || _c === void 0 ? void 0 : _c.parts) === null || _d === void 0 ? void 0 : _d[0]) === null || _e === void 0 ? void 0 : _e.text;
        if (!responseText || typeof responseText !== "string") {
            return { relatedSkills: [] };
        }
        // 7. Parse and Filter Response
        let cleanJson = responseText.trim();
        if (cleanJson.startsWith("```")) {
            cleanJson = cleanJson
                .replace(/^```json\s*/i, "")
                .replace(/^```\s*/, "")
                .replace(/```$/, "")
                .trim();
        }
        let parsedSkills;
        try {
            parsedSkills = JSON.parse(cleanJson);
        }
        catch (e) {
            console.error("Failed to parse related skills JSON:", e);
            return { relatedSkills: [] };
        }
        if (!Array.isArray(parsedSkills)) {
            return { relatedSkills: [] };
        }
        const lowerExisting = new Set(cleanedSkills.map((s) => s.toLowerCase()));
        const relatedSkills = parsedSkills
            .map((s) => String(s).trim())
            .filter((s) => s.length > 0 && !lowerExisting.has(s.toLowerCase()))
            .slice(0, 5);
        return {
            relatedSkills,
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        console.error("Unhandled error in getRelatedSkills:", error);
        return { relatedSkills: [] };
    }
});
//# sourceMappingURL=index.js.map