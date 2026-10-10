import * as crypto from "crypto";
import * as nodemailer from "nodemailer";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

async function sendOtpEmail(toEmail: string, otpCode: string): Promise<boolean> {
  const smtpHost = process.env.SMTP_HOST || "smtp.gmail.com";
  const smtpPort = parseInt(process.env.SMTP_PORT || "465");
  const smtpUser = process.env.SMTP_USER || process.env.EMAIL_USER || "";
  const smtpPass = process.env.SMTP_PASS || process.env.EMAIL_PASS || "";

  if (!smtpUser || !smtpPass) {
    console.error(`[sendOtpEmail] SMTP credentials (SMTP_USER/SMTP_PASS) not configured in environment.`);
    return false;
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const mailOptions = {
    from: `"TalentBay Security" <${smtpUser}>`,
    to: toEmail,
    subject: "Your TalentBay Email Verification Code",
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
        <h2 style="color: #008080;">Verify Your Email Address</h2>
        <p>Thank you for registering with TalentBay Candidate App.</p>
        <p>Your 6-digit email verification code is:</p>
        <div style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #008080; margin: 20px 0;">
          ${otpCode}
        </div>
        <p>This code will expire in 10 minutes. If you did not request this, please ignore this email.</p>
        <br/>
        <p>Best regards,<br/>The TalentBay Team</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`[sendOtpEmail] Verification email successfully sent to ${toEmail}`);
    return true;
  } catch (err: any) {
    console.error(`[sendOtpEmail] Error sending email to ${toEmail}:`, err);
    return false;
  }
}

export const onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

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
      
      const chatData = chatDoc.data()!;
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
             jobTitle = jobDoc.data()?.roleName || "Job";
           }
         } catch(e) { }
      }

      if (isSenderRecruiter) {
        const recruiterDoc = await db.collection("recruiters").doc(senderId).get();
        if (recruiterDoc.exists) {
          senderName = recruiterDoc.data()?.fullName || "Recruiter";
          senderImageUrl = recruiterDoc.data()?.photoUrl || defaultIcon;
        }
      } else {
        const candidateDoc = await db.collection("candidates").doc(senderId).get();
        if (candidateDoc.exists) {
          senderName = candidateDoc.data()?.firstName 
            ? `${candidateDoc.data()?.firstName} ${candidateDoc.data()?.lastName}`.trim()
            : "Candidate";
          senderImageUrl = candidateDoc.data()?.photoUrl || defaultIcon;
        }
      }

      // 3. Get recipient FCM Token
      let fcmToken = null;
      if (isSenderRecruiter) {
        // Recipient is candidate
        const candidateDoc = await db.collection("candidates").doc(recipientId).get();
        fcmToken = candidateDoc.data()?.fcmToken;
      } else {
        // Recipient is recruiter
        const recruiterDoc = await db.collection("recruiters").doc(recipientId).get();
        fcmToken = recruiterDoc.data()?.fcmToken;
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
      } else {
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

    } catch (error) {
      console.error("Error processing notification:", error);
    }

    return null;
  });

export const generateJobDescription = onCall(
  { secrets: ["GEMINI_API_KEY"] },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Recruiter only)
      const recruiterDoc = await db.collection("recruiters").doc(userId).get();
      if (!recruiterDoc.exists) {
        throw new HttpsError("permission-denied", "Only authenticated recruiters are authorized to generate job descriptions.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { role, skills } = data;

      if (!role || typeof role !== "string" || role.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Role is required and must be a non-empty string.");
      }
      if (role.length > 100) {
        throw new HttpsError("invalid-argument", "Job role is too long (maximum 100 characters).");
      }

      if (!skills || !Array.isArray(skills)) {
        throw new HttpsError("invalid-argument", "Skills must be provided as a list.");
      }
      if (skills.length > 20) {
        throw new HttpsError("invalid-argument", "Too many skills provided (maximum 20).");
      }

      for (let i = 0; i < skills.length; i++) {
        const skill = skills[i];
        if (typeof skill !== "string") {
          throw new HttpsError("invalid-argument", `Skill at index ${i} must be a string.`);
        }
        if (skill.trim().length === 0) {
          throw new HttpsError("invalid-argument", `Skill at index ${i} cannot be empty.`);
        }
        if (skill.length > 50) {
          throw new HttpsError("invalid-argument", `Skill "${skill}" is too long (maximum 50 characters).`);
        }
      }

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Configurable Model Name (Default to gemini-1.5-flash)
      const model = process.env.GEMINI_MODEL || "gemini-1.5-flash";

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
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
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
        }
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => "");
        console.error(`Gemini API returned status ${response.status}: ${errText}`);
        throw new HttpsError("internal", "Failed to generate job description from AI service.");
      }

      const responseData: any = await response.json();
      const responseText = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!responseText || typeof responseText !== "string") {
        console.error("Gemini API response did not contain text content:", JSON.stringify(responseData));
        throw new HttpsError("internal", "Received invalid output format from AI service.");
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

      let parsedData: any;
      try {
        parsedData = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("Failed to parse Gemini response as JSON. Raw text:", responseText, "Error:", e);
        throw new HttpsError("internal", "AI generated a malformed response format. Please try again.");
      }

      const description = parsedData.description;
      const responsibilities = parsedData.responsibilities;
      const requirements = parsedData.requirements;

      if (typeof description !== "string" || !description.trim()) {
        console.error("Parsed response missing description field:", parsedData);
        throw new HttpsError("internal", "AI description was empty or malformed.");
      }

      if (!Array.isArray(responsibilities)) {
        console.error("Parsed response responsibilities field is not an array:", parsedData);
        throw new HttpsError("internal", "AI responsibilities were empty or malformed.");
      }

      if (!Array.isArray(requirements)) {
        console.error("Parsed response requirements field is not an array:", parsedData);
        throw new HttpsError("internal", "AI requirements were empty or malformed.");
      }

      return {
        description: description.trim(),
        responsibilities: responsibilities.map((r: any) => String(r).trim()).filter(Boolean),
        requirements: requirements.map((r: any) => String(r).trim()).filter(Boolean),
      };

    } catch (error: any) {
      // Avoid leaking internal errors (except HttpsError which is intentional)
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in generateJobDescription:", error);
      throw new HttpsError("internal", "An error occurred while generating the job description.");
    }
  }
);


export const bulkPostJobs = onCall(
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;
    const { jobs } = request.data;

    if (!jobs || !Array.isArray(jobs)) {
      throw new HttpsError("invalid-argument", "Jobs list must be provided as an array.");
    }

    try {
      // 2. Role check in users collection
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists || userDoc.data()?.role !== "recruiter") {
        throw new HttpsError("permission-denied", "Unauthorized. Only recruiters can perform this action.");
      }

      // 3. Fetch recruiter profile and verify subscription
      const recruiterDoc = await db.collection("recruiters").doc(userId).get();
      if (!recruiterDoc.exists) {
        throw new HttpsError("permission-denied", "Recruiter profile details not found.");
      }

      const recruiterData = recruiterDoc.data() || {};
      const isSubscribed = recruiterData.isSubscribed || false;
      const companyId = recruiterData.companyId || "";

      if (!isSubscribed) {
        throw new HttpsError("permission-denied", "Your account is not subscribed. Bulk job posting is disabled.");
      }

      if (!companyId) {
        throw new HttpsError("failed-precondition", "Recruiter is not linked to any company profile.");
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
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(postedAt.toDate().getTime() + 30 * 24 * 60 * 60 * 1000)
      );

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
            city: job.jobLocation?.city || "",
            state: job.jobLocation?.state || "",
            country: job.jobLocation?.country || "",
          },
          vacancies: parseInt(job.vacancies) || 1,
          officeCount: parseInt(job.officeCount) || 1,
          experienceRequired: {
            minYears: parseInt(job.experienceRequired?.minYears) || 0,
            maxYears: parseInt(job.experienceRequired?.maxYears) || 0,
          },
          salary: {
            min: parseFloat(job.salary?.min) || 0.0,
            max: parseFloat(job.salary?.max) || 0.0,
            currency: job.salary?.currency || "INR",
            type: job.salary?.type || "CTC",
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
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in bulkPostJobs:", error);
      throw new HttpsError("internal", `An error occurred while bulk posting: ${error.message}`);
    }
  }
);

export const enhanceText = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Candidate verification)
      const candidateDoc = await db.collection("candidates").doc(userId).get();
      const userDoc = await db.collection("users").doc(userId).get();
      const isCandidate = candidateDoc.exists || (userDoc.exists && userDoc.data()?.role === "candidate");
      if (!isCandidate) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { text, type, context } = data;

      if (!text || typeof text !== "string" || text.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Text is required and must be a non-empty string.");
      }
      if (text.length > 4000) {
        throw new HttpsError("invalid-argument", "Input text is too long (maximum 4000 characters).");
      }

      const title = context?.title && typeof context.title === "string" ? context.title.slice(0, 200).trim() : "";
      const company = context?.company && typeof context.company === "string" ? context.company.slice(0, 200).trim() : "";
      const role = context?.role && typeof context.role === "string" ? context.role.slice(0, 200).trim() : "";

      let prompt = "";
      if (type === "summary") {
        prompt = `Enhance this professional summary/bio for a candidate job profile. Headline: "${title}". Current Description: "${text.trim()}". Make it compelling, professional, and highlight key strengths. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
      } else if (type === "experience") {
        prompt = `Enhance this job description for a candidate resume. Job Title: "${title}", Company: "${company}". Current Description: "${text.trim()}". Make it professional, focusing on achievements and responsibilities. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
      } else if (type === "project") {
        prompt = `Enhance this project description for a candidate portfolio. Title: "${title}", Role: "${role}". Current Description: "${text.trim()}". Make it professional, highlighting technical challenges and outcomes. Return ONLY the enhanced description text without markdown blocks, commentary, or quotes.`;
      } else {
        prompt = `Enhance the following professional description for a resume/portfolio profile. Text: "${text.trim()}". Make it concise, professional, and impactful. Return ONLY the enhanced text without markdown blocks, commentary, or quotes.`;
      }

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Model Selection & REST Invocation with Auto-Fallback
      const candidateModels = [
        process.env.GEMINI_MODEL,
        "gemini-1.5-flash",
        "gemini-2.0-flash",
        "gemini-2.5-flash",
        "gemini-1.5-pro",
        "gemini-flash-latest",
      ].filter((m, i, self) => m && m.trim().length > 0 && self.indexOf(m) === i) as string[];

      let lastErrorText = "";
      for (const modelName of candidateModels) {
        try {
          const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
            {
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
            }
          );

          if (response.ok) {
            const responseData: any = await response.json();
            const responseText = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
            if (responseText && typeof responseText === "string") {
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
              console.log(`[enhanceText] Successfully generated text using model: ${modelName}`);
              return {
                enhancedText,
              };
            }
          } else {
            lastErrorText = await response.text().catch(() => "");
            console.warn(`[enhanceText] Model ${modelName} returned status ${response.status}: ${lastErrorText}`);
          }
        } catch (err: any) {
          console.warn(`[enhanceText] Exception trying model ${modelName}:`, err);
        }
      }

      console.error("[enhanceText] All candidate Gemini models failed. Last error:", lastErrorText);
      throw new HttpsError("internal", "Failed to generate enhanced text from AI service.");
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in enhanceText:", error);
      throw new HttpsError("internal", "An error occurred while enhancing text.");
    }
  }
);

export const generateAssessmentQuestions = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Candidate verification)
      const candidateDoc = await db.collection("candidates").doc(userId).get();
      if (!candidateDoc.exists) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { skill, difficulty = "Medium", count = 15 } = data;

      if (!skill || typeof skill !== "string" || skill.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Skill is required and must be a non-empty string.");
      }
      if (skill.length > 100) {
        throw new HttpsError("invalid-argument", "Skill name is too long (maximum 100 characters).");
      }

      const validDifficulties = ["Easy", "Medium", "Hard"];
      const validatedDifficulty = validDifficulties.includes(difficulty) ? difficulty : "Medium";

      const questionCount = typeof count === "number" && count >= 1 && count <= 30 ? Math.floor(count) : 15;

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Model Selection & REST Invocation with Auto-Fallback
      const candidateModels = [
        process.env.GEMINI_MODEL,
        "gemini-1.5-flash",
        "gemini-2.0-flash",
        "gemini-2.5-flash",
        "gemini-1.5-pro",
        "gemini-flash-latest",
      ].filter((m, i, self) => m && m.trim().length > 0 && self.indexOf(m) === i) as string[];

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

      // 6. Invoke Gemini REST API with fallback across active models
      let responseText = "";
      let lastErrorText = "";

      for (const modelName of candidateModels) {
        try {
          const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
            {
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
            }
          );

          if (response.ok) {
            const responseData: any = await response.json();
            const text = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
            if (text && typeof text === "string") {
              responseText = text;
              console.log(`[generateAssessmentQuestions] Successfully generated content using model: ${modelName}`);
              break;
            }
          } else {
            lastErrorText = await response.text().catch(() => "");
            console.warn(`Gemini API model ${modelName} returned status ${response.status}: ${lastErrorText}`);
          }
        } catch (e: any) {
          lastErrorText = e.message || String(e);
          console.warn(`Gemini API request failed for model ${modelName}: ${lastErrorText}`);
        }
      }

      if (!responseText || typeof responseText !== "string") {
        console.error("All candidate Gemini models failed. Last error:", lastErrorText);
        throw new HttpsError("internal", "Failed to generate assessment questions from AI service.");
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

      let parsedList: any[];
      try {
        parsedList = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("Failed to parse Gemini response as JSON. Raw text:", responseText, "Error:", e);
        throw new HttpsError("internal", "AI generated a malformed response format. Please try again.");
      }

      if (!Array.isArray(parsedList) || parsedList.length === 0) {
        console.error("Parsed response is not a non-empty array:", parsedList);
        throw new HttpsError("internal", "AI failed to generate valid assessment questions.");
      }

      const now = Date.now();
      const sanitizedQuestions = [];

      for (let i = 0; i < parsedList.length; i++) {
        const item = parsedList[i];
        if (!item || typeof item !== "object") continue;

        const questionText = typeof item.question === "string" ? item.question.trim() : "";
        const options = Array.isArray(item.options) ? item.options.map((opt: any) => String(opt).trim()).filter(Boolean) : [];
        let correctIndex = typeof item.correctAnswerIndex === "number" ? Math.floor(item.correctAnswerIndex) : 0;

        if (!questionText || options.length < 2) continue;
        if (correctIndex < 0 || correctIndex >= options.length) correctIndex = 0;

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
        throw new HttpsError("internal", "AI generated zero valid questions.");
      }

      return {
        questions: sanitizedQuestions.slice(0, questionCount),
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in generateAssessmentQuestions:", error);
      throw new HttpsError("internal", "An error occurred while generating assessment questions.");
    }
  }
);

export const getRelatedSkills = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      // 2. Authorization Check (Candidate verification)
      const candidateDoc = await db.collection("candidates").doc(userId).get();
      if (!candidateDoc.exists) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      // 3. Payload and Input Validation
      const data = request.data;
      if (!data) {
        throw new HttpsError("invalid-argument", "Missing request payload.");
      }

      const { currentSkills } = data;

      if (!currentSkills || !Array.isArray(currentSkills) || currentSkills.length === 0) {
        return { relatedSkills: [] };
      }

      const cleanedSkills = currentSkills
        .filter((s: any) => typeof s === "string" && s.trim().length > 0)
        .map((s: string) => s.trim())
        .slice(0, 50);

      if (cleanedSkills.length === 0) {
        return { relatedSkills: [] };
      }

      // 4. Secure API Key Retrieval
      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        console.error("GEMINI_API_KEY secret is not configured on the backend.");
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      // 5. Model Selection & REST Invocation with Auto-Fallback
      const candidateModels = [
        process.env.GEMINI_MODEL,
        "gemini-1.5-flash",
        "gemini-2.0-flash",
        "gemini-2.5-flash",
        "gemini-1.5-pro",
        "gemini-flash-latest",
      ].filter((m, i, self) => m && m.trim().length > 0 && self.indexOf(m) === i) as string[];

      const prompt = `Given the following list of technical skills: ${cleanedSkills.join(", ")}.
Suggest 5 related technical skills that this candidate would benefit from learning or might already know.

The output must be a valid JSON array of strings.
Example: ["Skill A", "Skill B", "Skill C"]
Do not include any markdown formatting.`;

      // 6. Invoke Gemini REST API with fallback
      let responseText = "";
      for (const modelName of candidateModels) {
        try {
          const response = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
            {
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
            }
          );

          if (response.ok) {
            const responseData: any = await response.json();
            const text = responseData?.candidates?.[0]?.content?.parts?.[0]?.text;
            if (text && typeof text === "string") {
              responseText = text;
              break;
            }
          }
        } catch (_) {}
      }

      if (!responseText) {
        return { relatedSkills: [] };
      }
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

      let parsedSkills: any[];
      try {
        parsedSkills = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("Failed to parse related skills JSON:", e);
        return { relatedSkills: [] };
      }

      if (!Array.isArray(parsedSkills)) {
        return { relatedSkills: [] };
      }

      const lowerExisting = new Set(cleanedSkills.map((s: string) => s.toLowerCase()));
      const relatedSkills = parsedSkills
        .map((s: any) => String(s).trim())
        .filter((s: string) => s.length > 0 && !lowerExisting.has(s.toLowerCase()))
        .slice(0, 5);

      return {
        relatedSkills,
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Unhandled error in getRelatedSkills:", error);
      return { relatedSkills: [] };
    }
  }
);

export const deleteUserAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to delete your account.");
    }

    const userId = request.auth.uid;
    console.log(`[deleteUserAccount] Initiating permanent deletion for UID: ${userId}`);

    try {
      // 2. Fetch recruiter profile to inspect company and personal assets
      const recruiterRef = db.collection("recruiters").doc(userId);
      const recruiterDoc = await recruiterRef.get();
      const recruiterData = recruiterDoc.exists ? recruiterDoc.data() : null;
      const companyId = recruiterData?.companyId;
      const recruiterPhotoUrl = recruiterData?.photoUrl;

      // 3. Handle Company Data with ownership safety
      if (companyId) {
        const companyRef = db.collection("companies").doc(companyId);
        const companyDoc = await companyRef.get();
        if (companyDoc.exists) {
          const companyData = companyDoc.data();
          const createdBy = companyData?.meta?.createdBy;

          // Check if other active recruiters belong to this company
          const otherRecruiters = await db
            .collection("recruiters")
            .where("companyId", "==", companyId)
            .get();

          const hasOtherRecruiters = otherRecruiters.docs.some(
            (doc) => doc.id !== userId
          );

          if (!hasOtherRecruiters && (createdBy === userId || !createdBy)) {
            // Delete company logo from Storage if hosted in bucket
            const logoUrl =
              companyData?.profile?.logoUrl || companyData?.logoUrl;
            if (logoUrl && typeof logoUrl === "string") {
              try {
                const bucket = admin.storage().bucket();
                const matches = logoUrl.match(/\/o\/([^?]+)/);
                if (matches && matches[1]) {
                  const decodedPath = decodeURIComponent(matches[1]);
                  await bucket
                    .file(decodedPath)
                    .delete()
                    .catch((e: any) => {
                      console.warn(
                        `[deleteUserAccount] Storage delete company logo warning: ${e.message}`
                      );
                    });
                }
              } catch (storageErr: any) {
                console.warn(
                  `[deleteUserAccount] Could not delete company logo from storage: ${storageErr.message}`
                );
              }
            }
            // Delete the company document
            await companyRef.delete();
            console.log(`[deleteUserAccount] Deleted company document: ${companyId}`);
          }
        }
      }

      // 4. Handle recruiter profile photo in Firebase Storage if any
      if (recruiterPhotoUrl && typeof recruiterPhotoUrl === "string") {
        try {
          const bucket = admin.storage().bucket();
          const matches = recruiterPhotoUrl.match(/\/o\/([^?]+)/);
          if (matches && matches[1]) {
            const decodedPath = decodeURIComponent(matches[1]);
            await bucket
              .file(decodedPath)
              .delete()
              .catch((e: any) => {
                console.warn(
                  `[deleteUserAccount] Storage delete recruiter photo warning: ${e.message}`
                );
              });
          }
        } catch (storageErr: any) {
          console.warn(
            `[deleteUserAccount] Could not delete recruiter photo from storage: ${storageErr.message}`
          );
        }
      }

      const batchSize = 400;
      let batch = db.batch();
      let opCount = 0;

      // 5. Delete recruiter notifications (notification_recruter)
      const notifQuery = await db
        .collection("notification_recruter")
        .where("recruiterId", "==", userId)
        .get();

      for (const doc of notifQuery.docs) {
        batch.delete(doc.ref);
        opCount++;
        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      console.log(`[deleteUserAccount] Deleted ${notifQuery.docs.length} recruiter notifications`);

      // 6. Handle Jobs & Applications posted by this recruiter
      const jobsQuery = await db
        .collection("jobs")
        .where("recruiterId", "==", userId)
        .get();

      for (const jobDoc of jobsQuery.docs) {
        const jobId = jobDoc.id;

        // Clean up applications for this job
        const appsQuery = await db
          .collection("job_applications")
          .where("jobId", "==", jobId)
          .get();

        for (const appDoc of appsQuery.docs) {
          batch.delete(appDoc.ref);
          opCount++;
          if (opCount >= batchSize) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
          }
        }

        // Delete the job doc
        batch.delete(jobDoc.ref);
        opCount++;
        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      console.log(`[deleteUserAccount] Deleted ${jobsQuery.docs.length} jobs created by recruiter`);

      // 7. Handle Chats & Messages
      const chatsQuery = await db
        .collection("chats")
        .where("recruiterId", "==", userId)
        .get();

      for (const chatDoc of chatsQuery.docs) {
        // Delete messages in subcollection
        const messagesQuery = await chatDoc.ref.collection("messages").get();
        for (const msgDoc of messagesQuery.docs) {
          batch.delete(msgDoc.ref);
          opCount++;
          if (opCount >= batchSize) {
            await batch.commit();
            batch = db.batch();
            opCount = 0;
          }
        }
        // Delete the chat document
        batch.delete(chatDoc.ref);
        opCount++;
        if (opCount >= batchSize) {
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      }
      console.log(`[deleteUserAccount] Deleted ${chatsQuery.docs.length} chat threads`);

      // 8. Delete user role doc and recruiter profile doc
      const userDocRef = db.collection("users").doc(userId);
      batch.delete(userDocRef);
      batch.delete(recruiterRef);
      opCount += 2;

      if (opCount > 0) {
        await batch.commit();
      }
      console.log(`[deleteUserAccount] Deleted users/${userId} and recruiters/${userId}`);

      // 9. Delete Firebase Auth User Record
      try {
        await admin.auth().deleteUser(userId);
        console.log(`[deleteUserAccount] Successfully deleted Firebase Auth user: ${userId}`);
      } catch (authErr: any) {
        if (authErr.code !== "auth/user-not-found") {
          console.error(`[deleteUserAccount] Error deleting Firebase Auth user:`, authErr);
          throw new HttpsError("internal", "Failed to delete authentication user record.");
        }
      }

      return {
        success: true,
        message: "User account and associated recruiter data permanently deleted.",
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("[deleteUserAccount] Unhandled error:", error);
      throw new HttpsError("internal", "An error occurred while deleting your account. Please try again.");
    }
  }
);




// ==========================================
// Razorpay Subscription Configuration
// ==========================================
const SUBSCRIPTION_PLANS = [
  {
    id: "7_days_trial",
    name: "7 Days Trial",
    price: 1,
    amountPaise: 100, // 1.00 INR (100 paise)
    durationDays: 7,
  },
  {
    id: "1_month",
    name: "1 Month",
    price: 399,
    amountPaise: 39900, // 399.00 INR (39900 paise)
    durationDays: 30,
  },
  {
    id: "3_months",
    name: "3 Months",
    price: 569,
    amountPaise: 56900, // 569.00 INR (56900 paise)
    durationDays: 90,
  },
  {
    id: "6_months",
    name: "6 Months",
    price: 1079,
    amountPaise: 107900, // 1079.00 INR (107900 paise)
    durationDays: 180,
  },
  // Legacy / Recruiter compatibility plans
  {
    id: "trial_60_days_1_rupee",
    name: "Trial (60 Days)",
    price: 1,
    amountPaise: 100,
    durationDays: 60,
  },
  {
    id: "monthly_1499",
    name: "Monthly Plan",
    price: 1499,
    amountPaise: 149900,
    durationDays: 30,
  },
  {
    id: "six_months_8549",
    name: "6 Months Plan",
    price: 8549,
    amountPaise: 854900,
    durationDays: 180,
  },
  {
    id: "yearly_17089",
    name: "Yearly Plan",
    price: 17089,
    amountPaise: 1708900,
    durationDays: 365,
  },
] as const;

/**
 * createRazorpayOrder (us-central1)
 * Creates a server-side order with Razorpay.
 */
export const createRazorpayOrder = onCall(
  { region: "us-central1" },
  async (request) => {
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to create an order.");
    }
    const uid = request.auth.uid;

    const data = request.data as { planId?: string };
    const planId = data?.planId;
    if (!planId) {
      throw new HttpsError("invalid-argument", "Plan ID is required.");
    }

    const plan = SUBSCRIPTION_PLANS.find((p) => p.id === planId);
    if (!plan) {
      throw new HttpsError("not-found", `Invalid subscription plan: ${planId}`);
    }

    // 2. Trial Plan Eligibility Verification
    if (plan.id === "trial_60_days_1_rupee") {
      const recruiterDoc = await db.collection("recruiters").doc(uid).get();
      if (recruiterDoc.exists) {
        const rData = recruiterDoc.data();
        if (rData?.subscriptionPlanId || rData?.subscriptionTier) {
          throw new HttpsError(
            "failed-precondition",
            "The introductory trial offer is only available for first-time recruiter accounts."
          );
        }
      }
    } else if (plan.id === "7_days_trial") {
      const candidateDoc = await db.collection("candidates").doc(uid).get();
      if (candidateDoc.exists && candidateDoc.data()?.hasUsedTrial === true) {
        throw new HttpsError(
          "failed-precondition",
          "The introductory trial offer is only available once per candidate."
        );
      }
    }

    // 3. Razorpay Secrets Validation
    const keyId = process.env.RAZORPAY_KEY_ID || "rzp_live_TdPCKnpedQNEW6";
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keySecret) {
      console.error("[createRazorpayOrder] RAZORPAY_KEY_SECRET is not configured.");
      throw new HttpsError("failed-precondition", "RAZORPAY_KEY_SECRET is not configured.");
    }

    // 4. Create Order via Razorpay REST API
    try {
      const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");
      const receipt = `ord_${uid.substring(0, 8)}_${Date.now()}`;

      const response = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: authHeader,
        },
        body: JSON.stringify({
          amount: plan.amountPaise,
          currency: "INR",
          receipt: receipt,
          notes: {
            uid: uid,
            planId: plan.id,
            planName: plan.name,
          },
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        console.error("[createRazorpayOrder] Razorpay API error:", response.status, errText);
        throw new HttpsError("internal", `Payment gateway order creation failed: ${errText}`);
      }

      const orderData = (await response.json()) as {
        id: string;
        amount: number;
        currency: string;
        receipt?: string;
      };

      console.log(`[createRazorpayOrder] Created order ${orderData.id} for user ${uid}, amount ${orderData.amount} ${orderData.currency}`);

      await db.collection("payment_transactions").doc(orderData.id).set({
        orderId: orderData.id,
        uid,
        planId: plan.id,
        planName: plan.name,
        amountPaise: plan.amountPaise,
        price: plan.price,
        durationDays: plan.durationDays,
        currency: orderData.currency || "INR",
        receipt: orderData.receipt || receipt,
        status: "created",
        gateway: "razorpay",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        orderId: orderData.id,
        id: orderData.id,
        amount: orderData.amount,
        currency: orderData.currency,
      };
    } catch (err: any) {
      if (err instanceof HttpsError) {
        throw err;
      }
      console.error("[createRazorpayOrder] Unexpected error creating order:", err);
      throw new HttpsError("internal", "An error occurred while creating your payment order.");
    }
  }
);

/**
 * verifyRazorpayPayment (us-central1)
 * Verifies Razorpay payment signature, verifies payment status with Razorpay API,
 * records payment receipt idempotently, and activates candidate or recruiter subscription using Firebase Admin SDK.
 */
export const verifyRazorpayPayment = onCall(
  { region: "us-central1", secrets: ["RAZORPAY_KEY_SECRET"] },
  async (request) => {
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to verify payment.");
    }
    const uid = request.auth.uid;

    const data = request.data as {
      paymentId?: string;
      orderId?: string;
      signature?: string;
      planId?: string;
    };

    const paymentId = data?.paymentId?.trim();
    if (!paymentId) {
      throw new HttpsError("invalid-argument", "Payment ID is required.");
    }

    const planId = data?.planId;
    if (!planId) {
      throw new HttpsError("invalid-argument", "Plan ID is required.");
    }

    const plan = SUBSCRIPTION_PLANS.find((p) => p.id === planId);
    if (!plan) {
      throw new HttpsError("not-found", `Invalid subscription plan: ${planId}`);
    }

    // 2. Razorpay Secrets Validation
    const keyId = process.env.RAZORPAY_KEY_ID || "rzp_live_TdPCKnpedQNEW6";
    const keySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!keySecret) {
      console.error("[verifyRazorpayPayment] RAZORPAY_KEY_SECRET is not configured.");
      throw new HttpsError("failed-precondition", "RAZORPAY_KEY_SECRET is not configured.");
    }

    // 3. Signature Verification (HMAC-SHA256) if signature & orderId provided
    if (data.signature && data.orderId) {
      const generatedSignature = crypto
        .createHmac("sha256", keySecret)
        .update(`${data.orderId}|${paymentId}`)
        .digest("hex");

      if (generatedSignature !== data.signature) {
        console.error("[verifyRazorpayPayment] Signature mismatch:", {
          received: data.signature,
          generated: generatedSignature,
        });
        throw new HttpsError("invalid-argument", "Payment signature verification failed.");
      }
      console.log(`[verifyRazorpayPayment] Signature verified successfully for payment ${paymentId}`);
    }

    // 4. Fetch and Verify Payment Details from Razorpay API
    const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    let rzpPayment: any = null;
    try {
      const rzpRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
        method: "GET",
        headers: { Authorization: authHeader },
      });

      if (!rzpRes.ok) {
        const errText = await rzpRes.text();
        console.error("[verifyRazorpayPayment] Razorpay fetch payment error:", rzpRes.status, errText);
        throw new HttpsError("not-found", "Payment record not found on payment gateway.");
      }

      rzpPayment = await rzpRes.json();
    } catch (fetchErr: any) {
      if (fetchErr instanceof HttpsError) throw fetchErr;
      console.error("[verifyRazorpayPayment] Error fetching payment from Razorpay:", fetchErr);
      throw new HttpsError("internal", "Could not verify payment with payment gateway.");
    }

    // 5. Verify Amount, Currency, and Status
    if (rzpPayment.currency !== "INR") {
      throw new HttpsError("invalid-argument", `Invalid payment currency: ${rzpPayment.currency}`);
    }

    if (Number(rzpPayment.amount) !== plan.amountPaise) {
      throw new HttpsError(
        "invalid-argument",
        `Payment amount mismatch. Expected: ₹${plan.price} (${plan.amountPaise} paise), Found: ${rzpPayment.amount} paise.`
      );
    }

    // Handle payment status: if authorized, capture it server-side if needed; if captured, good.
    if (rzpPayment.status === "authorized") {
      try {
        const captureRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}/capture`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: authHeader,
          },
          body: JSON.stringify({
            amount: plan.amountPaise,
            currency: "INR",
          }),
        });
        if (captureRes.ok) {
          rzpPayment = await captureRes.json();
          console.log(`[verifyRazorpayPayment] Captured authorized payment ${paymentId}`);
        }
      } catch (capErr) {
        console.warn("[verifyRazorpayPayment] Capture attempt warning:", capErr);
      }
    }

    if (rzpPayment.status !== "captured") {
      throw new HttpsError(
        "failed-precondition",
        `Payment is not yet captured (Status: ${rzpPayment.status}). Please wait or complete payment.`
      );
    }

    // 6. Check user type (Candidate vs Recruiter)
    const userDoc = await db.collection("users").doc(uid).get();
    const userRole = userDoc.data()?.role;
    const candidateDoc = await db.collection("candidates").doc(uid).get();
    const isCandidate = userRole === "candidate" || candidateDoc.exists;

    // 7. Calculate Expiry Date & Perform Admin SDK Writes
    const now = new Date();
    const expiryDate = new Date(now.getTime() + plan.durationDays * 24 * 60 * 60 * 1000);
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
    const serverTime = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    if (isCandidate) {
      // 7a. Idempotency Check on /candidates/{uid}/payments/{paymentId}
      const paymentDocRef = db
        .collection("candidates")
        .doc(uid)
        .collection("payments")
        .doc(paymentId);

      const existingPayment = await paymentDocRef.get();
      if (existingPayment.exists && existingPayment.data()?.status === "success") {
        console.log(`[verifyRazorpayPayment] Payment ${paymentId} already processed idempotently for candidate.`);
        return {
          success: true,
          verified: true,
          alreadyProcessed: true,
          message: "Payment has already been verified and activated.",
        };
      }

      // Write payment receipt under candidates
      batch.set(
        paymentDocRef,
        {
          paymentId: paymentId,
          orderId: data.orderId || rzpPayment.order_id || null,
          signature: data.signature || null,
          planId: plan.id,
          planName: plan.name,
          amount: plan.price,
          amountPaise: plan.amountPaise,
          currency: "INR",
          durationDays: plan.durationDays,
          status: "success",
          method: rzpPayment.method || "razorpay",
          email: rzpPayment.email || null,
          contact: rzpPayment.contact || null,
          createdAt: serverTime,
          verifiedAt: serverTime,
          expiryDate: expiryTimestamp,
        },
        { merge: true }
      );

      // Update canonical candidate profile in /candidates/{uid}
      const candidateRef = db.collection("candidates").doc(uid);
      const candidateUpdate: any = {
        isPremium: true,
        subscriptionStatus: "active",
        subscriptionExpiryDate: expiryDate.toISOString(),
        subscriptionPlanId: plan.id,
        razorpaySubscriptionId: paymentId,
        razorpayPaymentId: paymentId,
        razorpayOrderId: data.orderId || rzpPayment.order_id || null,
        lastUpdated: now.toISOString(),
      };
      if (plan.id === "7_days_trial") {
        candidateUpdate.hasUsedTrial = true;
      }
      batch.set(candidateRef, candidateUpdate, { merge: true });

      // Update /users/{uid}
      const userRef = db.collection("users").doc(uid);
      batch.set(
        userRef,
        {
          isPremium: true,
          subscriptionPlanId: plan.id,
          subscriptionExpiry: expiryTimestamp,
          updatedAt: serverTime,
        },
        { merge: true }
      );

      await batch.commit();
      console.log(`[verifyRazorpayPayment] Successfully activated candidate subscription for user ${uid}, plan ${plan.id}, expiry ${expiryDate.toISOString()}`);
    } else {
      // Recruiter workflow
      const paymentDocRef = db
        .collection("recruiters")
        .doc(uid)
        .collection("payments")
        .doc(paymentId);

      const existingPayment = await paymentDocRef.get();
      if (existingPayment.exists && existingPayment.data()?.status === "success") {
        console.log(`[verifyRazorpayPayment] Payment ${paymentId} already processed idempotently for recruiter.`);
        return {
          success: true,
          verified: true,
          alreadyProcessed: true,
          message: "Payment has already been verified and activated.",
        };
      }

      batch.set(
        paymentDocRef,
        {
          paymentId: paymentId,
          orderId: data.orderId || rzpPayment.order_id || null,
          signature: data.signature || null,
          planId: plan.id,
          planName: plan.name,
          amount: plan.price,
          amountPaise: plan.amountPaise,
          currency: "INR",
          durationDays: plan.durationDays,
          status: "success",
          method: rzpPayment.method || "razorpay",
          email: rzpPayment.email || null,
          contact: rzpPayment.contact || null,
          createdAt: serverTime,
          verifiedAt: serverTime,
          expiryDate: expiryTimestamp,
        },
        { merge: true }
      );

      const recruiterRef = db.collection("recruiters").doc(uid);
      batch.set(
        recruiterRef,
        {
          isSubscribed: true,
          subscriptionPlanId: plan.id,
          subscriptionTier: plan.id,
          subscriptionExpiry: expiryTimestamp,
          subscriptionStartDate: serverTime,
          subscriptionDate: serverTime,
          isSubscriptionCancelled: false,
          razorpaySubscriptionId: paymentId,
          paymentId: paymentId,
          razorpayPaymentId: paymentId,
          razorpayOrderId: data.orderId || rzpPayment.order_id || null,
          paymentRef: paymentId,
          subscriptionAmount: plan.price,
          subscriptionAmountPaise: plan.amountPaise,
          updatedAt: serverTime,
          lastPayment: {
            paymentId: paymentId,
            orderId: data.orderId || rzpPayment.order_id || null,
            planId: plan.id,
            planName: plan.name,
            amount: plan.price,
            amountPaise: plan.amountPaise,
            currency: "INR",
            durationDays: plan.durationDays,
            status: "success",
            verifiedAt: serverTime,
            expiryDate: expiryTimestamp,
          },
        },
        { merge: true }
      );

      const userRef = db.collection("users").doc(uid);
      batch.set(
        userRef,
        {
          isSubscribed: true,
          subscriptionPlanId: plan.id,
          subscriptionExpiry: expiryTimestamp,
          updatedAt: serverTime,
        },
        { merge: true }
      );

      await batch.commit();
      console.log(`[verifyRazorpayPayment] Successfully activated recruiter subscription for user ${uid}, plan ${plan.id}, expiry ${expiryDate.toISOString()}`);
    }

    return {
      success: true,
      verified: true,
      expiryDate: expiryDate.toISOString(),
      planId: plan.id,
      paymentId: paymentId,
    };
  }
);

export const sendEmailOtp = onCall(
  { region: "us-central1", secrets: ["SMTP_USER", "SMTP_PASS"] },
  async (request) => {
    const data = request.data;
    const email = (data?.email || "").trim().toLowerCase();
    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "A valid email address is required.");
    }

    // Check if email already registered in auth or users collection
    try {
      const existingUser = await admin.auth().getUserByEmail(email).catch(() => null);
      if (existingUser) {
        throw new HttpsError("already-exists", "An account with this email address already exists. Please log in.");
      }
    } catch (err: any) {
      if (err instanceof HttpsError) throw err;
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = crypto.createHash("sha256").update(`${email}:${otp}`).digest("hex");
    const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000));

    await db.collection("email_otps").doc(email).set({
      email: email,
      otpHash: otpHash,
      expiresAt: expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[sendEmailOtp] Generated OTP for ${email}`);

    const emailSent = await sendOtpEmail(email, otp);
    if (!emailSent) {
      throw new HttpsError("internal", "Unable to send verification email. Please contact support or try again later.");
    }

    return {
      success: true,
      message: "OTP sent successfully to email.",
    };
  }
);

export const verifyEmailOtp = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const email = (data?.email || "").trim().toLowerCase();
    const otp = (data?.otp || "").trim();

    if (!email || !otp || otp.length !== 6) {
      throw new HttpsError("invalid-argument", "Valid email and 6-digit OTP are required.");
    }

    const otpDocRef = db.collection("email_otps").doc(email);
    const otpDoc = await otpDocRef.get();

    if (!otpDoc.exists) {
      throw new HttpsError("not-found", "No OTP code request found for this email. Please request a new code.");
    }

    const otpData = otpDoc.data()!;
    const expiresAt = (otpData.expiresAt as admin.firestore.Timestamp).toDate();

    if (Date.now() > expiresAt.getTime()) {
      await otpDocRef.delete();
      throw new HttpsError("deadline-exceeded", "OTP has expired. Please request a new code.");
    }

    if (otpData.attempts >= 5) {
      await otpDocRef.delete();
      throw new HttpsError("resource-exhausted", "Too many failed attempts. Please request a new OTP code.");
    }

    const inputHash = crypto.createHash("sha256").update(`${email}:${otp}`).digest("hex");

    if (inputHash !== otpData.otpHash) {
      await otpDocRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      throw new HttpsError("invalid-argument", "Invalid OTP code. Please check and try again.");
    }

    await otpDocRef.delete();

    return {
      success: true,
      verified: true,
      message: "Email successfully verified.",
    };
  }
);

function razorpayAuthHeader(keyId: string, keySecret: string): string {
  return "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");
}

function getRazorpayKeys(): { keyId: string; keySecret: string } {
  const keyId = process.env.RAZORPAY_KEY_ID || "rzp_live_TdPCKnpedQNEW6";
  const keySecret = process.env.RAZORPAY_KEY_SECRET || "";
  if (!keySecret) {
    throw new HttpsError("failed-precondition", "Payment gateway is not configured. Please try again later.");
  }
  return { keyId, keySecret };
}

async function razorpayRequest(
  path: string,
  method: "GET" | "POST",
  body?: Record<string, unknown>
): Promise<any> {
  const { keyId, keySecret } = getRazorpayKeys();
  const response = await fetch(`https://api.razorpay.com/v1/${path}`, {
    method,
    headers: {
      Authorization: razorpayAuthHeader(keyId, keySecret),
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    const errText = await response.text();
    console.error(`[razorpayRequest] ${method} ${path} failed:`, response.status, errText);
    throw new HttpsError("internal", "Could not confirm this payment with the payment gateway.");
  }
  return response.json();
}

async function activateCandidateSubscription(params: {
  uid: string;
  plan: (typeof SUBSCRIPTION_PLANS)[number];
  payment: any;
  orderId: string;
  signature?: string | null;
}): Promise<{ expiryDate: string; alreadyProcessed: boolean }> {
  const { uid, plan, payment, orderId, signature } = params;
  const paymentId = String(payment.id);
  const paymentDocRef = db.collection("candidates").doc(uid).collection("payments").doc(paymentId);
  const existingPayment = await paymentDocRef.get();
  if (existingPayment.exists && existingPayment.data()?.status === "success") {
    const existingExpiry = existingPayment.data()?.expiryDate;
    let expiryDate = "";
    if (existingExpiry?.toDate) {
      expiryDate = existingExpiry.toDate().toISOString();
    }
    return { expiryDate, alreadyProcessed: true };
  }

  const now = new Date();
  const expiryDate = new Date(now.getTime() + plan.durationDays * 24 * 60 * 60 * 1000);
  const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
  const serverTime = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  batch.set(
    paymentDocRef,
    {
      paymentId,
      orderId,
      signature: signature || null,
      planId: plan.id,
      planName: plan.name,
      amount: plan.price,
      amountPaise: plan.amountPaise,
      currency: "INR",
      durationDays: plan.durationDays,
      status: "success",
      method: payment.method || "razorpay",
      email: payment.email || null,
      contact: payment.contact || null,
      gatewayStatus: payment.status || "captured",
      createdAt: serverTime,
      verifiedAt: serverTime,
      expiryDate: expiryTimestamp,
    },
    { merge: true }
  );

  const candidateUpdate: Record<string, unknown> = {
    isPremium: true,
    subscriptionStatus: "active",
    subscriptionExpiryDate: expiryDate.toISOString(),
    subscriptionPlanId: plan.id,
    razorpaySubscriptionId: paymentId,
    razorpayPaymentId: paymentId,
    razorpayOrderId: orderId,
    lastUpdated: now.toISOString(),
  };
  if (plan.id === "7_days_trial") {
    candidateUpdate.hasUsedTrial = true;
  }
  batch.set(db.collection("candidates").doc(uid), candidateUpdate, { merge: true });
  batch.set(
    db.collection("users").doc(uid),
    {
      isPremium: true,
      subscriptionPlanId: plan.id,
      subscriptionExpiry: expiryTimestamp,
      updatedAt: serverTime,
    },
    { merge: true }
  );
  batch.set(
    db.collection("payment_transactions").doc(orderId),
    {
      status: "captured",
      paymentId,
      outcome: "subscribed",
      uid,
      planId: plan.id,
      updatedAt: serverTime,
      subscriptionExpiry: expiryTimestamp,
    },
    { merge: true }
  );

  await batch.commit();
  return { expiryDate: expiryDate.toISOString(), alreadyProcessed: false };
}

async function markTransaction(
  orderId: string,
  patch: Record<string, unknown>
): Promise<void> {
  if (!orderId) return;
  await db.collection("payment_transactions").doc(orderId).set(
    {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/**
 * Backend is the source of truth. A Razorpay success callback is ignored until
 * this function sees a captured payment for an order this user created.
 */
async function settleRazorpayOrder(params: {
  uid: string;
  orderId?: string;
  paymentId?: string;
  signature?: string;
  clientPlanId?: string;
}): Promise<Record<string, unknown>> {
  let orderId = (params.orderId || "").trim();
  const paymentId = (params.paymentId || "").trim();

  const txSnap = orderId
    ? await db.collection("payment_transactions").doc(orderId).get()
    : null;
  let tx = txSnap?.exists ? txSnap.data() || null : null;

  if (tx && tx.uid && tx.uid !== params.uid) {
    throw new HttpsError("permission-denied", "This payment does not belong to your account.");
  }

  let razorpayOrder: any = null;
  if (orderId) {
    try {
      razorpayOrder = await razorpayRequest(`orders/${orderId}`, "GET");
    } catch (err) {
      if (!tx) throw err;
      console.warn("[settleRazorpayOrder] Order fetch failed, using stored transaction:", err);
    }
  }

  const notesUid = razorpayOrder?.notes?.uid || tx?.uid;
  if (notesUid && notesUid !== params.uid) {
    throw new HttpsError("permission-denied", "This payment does not belong to your account.");
  }

  const planId = (tx?.planId || razorpayOrder?.notes?.planId || params.clientPlanId || "").toString();
  const plan = SUBSCRIPTION_PLANS.find((item) => item.id === planId);
  if (!plan) {
    throw new HttpsError("not-found", "We could not match this payment to a subscription plan.");
  }

  if (params.signature && orderId && paymentId) {
    const { keySecret } = getRazorpayKeys();
    const generatedSignature = crypto
      .createHmac("sha256", keySecret)
      .update(`${orderId}|${paymentId}`)
      .digest("hex");
    if (generatedSignature !== params.signature) {
      throw new HttpsError("invalid-argument", "Payment signature verification failed.");
    }
  }

  let payments: any[] = [];
  if (orderId) {
    const listed = await razorpayRequest(`orders/${orderId}/payments`, "GET");
    payments = Array.isArray(listed?.items) ? listed.items : [];
  }
  if (paymentId && !payments.some((item) => item.id === paymentId)) {
    try {
      const single = await razorpayRequest(`payments/${paymentId}`, "GET");
      if (single) payments.push(single);
      if (!orderId && single?.order_id) orderId = String(single.order_id);
    } catch (err) {
      console.warn("[settleRazorpayOrder] Could not fetch payment id:", err);
    }
  }

  const captured = payments.find((item) => item.status === "captured");
  const authorized = payments.find((item) => item.status === "authorized");
  const refunded = payments.find((item) => item.status === "refunded");
  let payment = captured || authorized || null;

  if (payment && payment.status === "authorized") {
    try {
      payment = await razorpayRequest(`payments/${payment.id}/capture`, "POST", {
        amount: plan.amountPaise,
        currency: "INR",
      });
    } catch (captureErr) {
      console.error("[settleRazorpayOrder] Capture failed:", captureErr);
      await markTransaction(orderId, {
        status: "authorized",
        paymentId: payment.id,
        outcome: "refund_pending",
        uid: params.uid,
        planId: plan.id,
      });
      return {
        success: false,
        verified: false,
        subscriptionActive: false,
        outcome: "refund_pending",
        orderId,
        paymentId: payment.id,
        message:
          `Payment ${payment.id} was authorized but could not be completed. ` +
          "If the amount was deducted, a refund will be issued within 5–7 working days.",
      };
    }
  }

  if (!payment || payment.status !== "captured") {
    const failed = payments.length > 0 && payments.every((item) => item.status === "failed");
    if (refunded && !captured) {
      await markTransaction(orderId, {
        status: "refunded",
        outcome: "failed",
        uid: params.uid,
        planId: plan.id,
        paymentId: refunded.id,
      });
      return {
        success: false,
        verified: false,
        subscriptionActive: false,
        outcome: "failed",
        orderId,
        paymentId: refunded.id,
        message: `Payment ${refunded.id} was refunded. Your subscription was not charged.`,
      };
    }
    await markTransaction(orderId, {
      status: failed ? "failed" : payments.length === 0 ? "created" : "pending",
      outcome: payments.length === 0 || failed ? "failed" : "pending",
      uid: params.uid,
      planId: plan.id,
      paymentId: payments[0]?.id || null,
    });
    if (payments.length === 0 || failed) {
      return {
        success: false,
        verified: false,
        subscriptionActive: false,
        outcome: "failed",
        orderId,
        paymentId: payments[0]?.id || null,
        message: failed
          ? "Payment failed. No subscription was activated. If any amount was deducted, the bank reverses it automatically."
          : "Payment was not completed. You have not been charged.",
      };
    }
    return {
      success: false,
      verified: false,
      subscriptionActive: false,
      outcome: "pending",
      orderId,
      paymentId: payments[0]?.id || null,
      message:
        "Your payment is still processing. We will activate the subscription when the bank confirms it. You will not be charged twice.",
    };
  }

  if (payment.currency !== "INR" || Number(payment.amount) !== plan.amountPaise) {
    await markTransaction(orderId, {
      status: "captured",
      outcome: "refund_pending",
      paymentId: payment.id,
      uid: params.uid,
      planId: plan.id,
      gatewayAmount: payment.amount,
    });
    return {
      success: false,
      verified: false,
      subscriptionActive: false,
      outcome: "refund_pending",
      orderId,
      paymentId: payment.id,
      message:
        `We received payment ${payment.id}, but the amount does not match this plan. ` +
        "The subscription was not activated. A refund will be issued within 5–7 working days.",
    };
  }

  if (payment.order_id && orderId && payment.order_id !== orderId) {
    throw new HttpsError("invalid-argument", "Payment does not match this order.");
  }

  try {
    const activated = await activateCandidateSubscription({
      uid: params.uid,
      plan,
      payment,
      orderId: orderId || payment.order_id,
      signature: params.signature || null,
    });
    return {
      success: true,
      verified: true,
      subscriptionActive: true,
      outcome: activated.alreadyProcessed ? "already_subscribed" : "subscribed",
      orderId: orderId || payment.order_id,
      paymentId: payment.id,
      planId: plan.id,
      expiryDate: activated.expiryDate,
      message: activated.alreadyProcessed
        ? "This payment is already applied. Your subscription is active."
        : "Payment confirmed. Your subscription is active.",
    };
  } catch (activationErr) {
    console.error("[settleRazorpayOrder] Activation failed after capture:", activationErr);
    await markTransaction(orderId || payment.order_id, {
      status: "captured",
      outcome: "refund_pending",
      paymentId: payment.id,
      uid: params.uid,
      planId: plan.id,
    });
    return {
      success: false,
      verified: false,
      subscriptionActive: false,
      outcome: "refund_pending",
      orderId: orderId || payment.order_id,
      paymentId: payment.id,
      message:
        `Payment ${payment.id} was received, but the subscription could not be activated. ` +
        "A refund will be issued within 5–7 working days if it stays inactive. Keep this transaction ID.",
    };
  }
}

export const confirmRazorpayPayment = onCall(
  { region: "us-central1", secrets: ["RAZORPAY_KEY_SECRET"] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to confirm a payment.");
    }
    const data = request.data as {
      orderId?: string;
      paymentId?: string;
      signature?: string;
      planId?: string;
    };
    if (!data?.orderId && !data?.paymentId) {
      throw new HttpsError("invalid-argument", "A payment or order ID is required.");
    }
    return settleRazorpayOrder({
      uid: request.auth.uid,
      orderId: data.orderId,
      paymentId: data.paymentId,
      signature: data.signature,
      clientPlanId: data.planId,
    });
  }
);

export const reconcileMyPayments = onCall(
  { region: "us-central1", secrets: ["RAZORPAY_KEY_SECRET"] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const uid = request.auth.uid;
    const snap = await db.collection("payment_transactions").where("uid", "==", uid).limit(15).get();
    let subscriptionActivated = false;
    let needsAttention = false;
    let message = "";

    for (const doc of snap.docs) {
      const status = doc.data().status;
      const outcome = doc.data().outcome;
      if (status === "captured" && outcome === "subscribed") continue;
      if (status === "failed" || status === "refunded") continue;
      try {
        const result = await settleRazorpayOrder({
          uid,
          orderId: doc.id,
          clientPlanId: doc.data().planId,
        });
        if (result.subscriptionActive === true) {
          subscriptionActivated = true;
          message = String(result.message || "");
        } else if (result.outcome === "refund_pending" || result.outcome === "pending") {
          needsAttention = true;
          message = String(result.message || message);
        }
      } catch (err) {
        console.warn(`[reconcileMyPayments] Could not settle ${doc.id}:`, err);
      }
    }

    return {
      success: true,
      subscriptionActivated,
      needsAttention,
      message,
    };
  }
);

function normalizeStoredPhone(phone: string): string {
  const trimmed = (phone || "").trim();
  if (!trimmed) return "";
  let cleaned = trimmed.replace(/[\s\-()]/g, "");
  if (cleaned.startsWith("+")) {
    const digits = cleaned.slice(1).replace(/\D/g, "");
    return digits ? `+${digits}` : "";
  }
  cleaned = cleaned.replace(/\D/g, "");
  if (!cleaned) return "";
  if (cleaned.length === 10) return `+91${cleaned}`;
  if (cleaned.length === 11 && cleaned.startsWith("0")) return `+91${cleaned.slice(1)}`;
  if (cleaned.length === 12 && cleaned.startsWith("91")) return `+${cleaned}`;
  return cleaned.startsWith("+") ? cleaned : `+${cleaned}`;
}

function phoneLookupVariants(phone: string): string[] {
  const normalized = normalizeStoredPhone(phone);
  const digits = normalized.replace(/\D/g, "");
  const last10 = digits.length >= 10 ? digits.slice(-10) : digits;
  const variants = new Set<string>();
  if (phone.trim()) variants.add(phone.trim());
  if (normalized) variants.add(normalized);
  if (digits) variants.add(digits);
  if (last10) {
    variants.add(last10);
    variants.add(`+91${last10}`);
    variants.add(`91${last10}`);
  }
  return Array.from(variants).filter(Boolean).slice(0, 10);
}

async function authUserHasEmail(uid: string): Promise<boolean> {
  try {
    const user = await admin.auth().getUser(uid);
    if (user.email) return true;
    return (user.providerData || []).some(
      (provider) => provider.providerId === "password" || provider.providerId === "google.com"
    );
  } catch {
    return false;
  }
}

async function isDisposablePhoneUser(uid: string): Promise<boolean> {
  try {
    const user = await admin.auth().getUser(uid);
    if (user.email) return false;
    const providers = (user.providerData || []).map((provider) => provider.providerId);
    if (providers.some((provider) => provider !== "phone")) return false;
    return providers.length === 0 || providers.every((provider) => provider === "phone");
  } catch (err: any) {
    return err?.code === "auth/user-not-found";
  }
}

async function findCandidateIdsForPhone(phoneNumber: string): Promise<string[]> {
  const variants = phoneLookupVariants(phoneNumber);
  const ids = new Set<string>();
  if (variants.length > 0) {
    const [byPhone, byUserPhone, byDigits] = await Promise.all([
      db.collection("candidates").where("phoneNumber", "in", variants).limit(10).get(),
      db.collection("users").where("phoneNumber", "in", variants).limit(10).get(),
      phoneNumber.replace(/\D/g, "").length >= 10
        ? db
            .collection("candidates")
            .where("phoneDigits", "==", phoneNumber.replace(/\D/g, "").slice(-10))
            .limit(10)
            .get()
            .catch(() => null)
        : Promise.resolve(null),
    ]);
    byPhone.docs.forEach((doc) => ids.add(doc.id));
    byUserPhone.docs.forEach((doc) => ids.add(doc.id));
    byDigits?.docs.forEach((doc) => ids.add(doc.id));
  }
  try {
    const authUser = await admin.auth().getUserByPhoneNumber(normalizeStoredPhone(phoneNumber));
    ids.add(authUser.uid);
  } catch {
    // Number is not linked on an auth user yet.
  }
  return Array.from(ids);
}

async function choosePrimaryCandidate(ids: string[]): Promise<string | null> {
  const registered: string[] = [];
  for (const id of ids) {
    // A phone-only Firebase user is created just by requesting an OTP.
    // That is not an account. Only an email (or Google) account can sign in.
    if (await authUserHasEmail(id)) registered.push(id);
  }
  if (registered.length === 0) return null;
  if (registered.length === 1) return registered[0];
  throw new HttpsError(
    "already-exists",
    "More than one account uses this mobile number. Sign in with your email and password."
  );
}

export const syncVerifiedPhone = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to save a mobile number.");
    }
    const uid = request.auth.uid;
    const phoneNumber = normalizeStoredPhone((request.data?.phoneNumber || "").toString());
    if (!phoneNumber || phoneNumber.replace(/\D/g, "").length < 8) {
      throw new HttpsError("invalid-argument", "Enter a valid mobile number.");
    }

    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists && userDoc.data()?.role && userDoc.data()?.role !== "candidate") {
      throw new HttpsError("permission-denied", "Only a candidate account can save this mobile number.");
    }

    const matches = await findCandidateIdsForPhone(phoneNumber);
    const otherRealAccounts: string[] = [];
    for (const id of matches) {
      if (id === uid) continue;
      if (await authUserHasEmail(id)) otherRealAccounts.push(id);
    }
    if (otherRealAccounts.length > 0) {
      throw new HttpsError(
        "already-exists",
        "This mobile number is already registered to another account. Sign in with that account, or use a different number."
      );
    }

    let phoneOwner: admin.auth.UserRecord | null = null;
    try {
      phoneOwner = await admin.auth().getUserByPhoneNumber(phoneNumber);
    } catch {
      phoneOwner = null;
    }

    if (phoneOwner && phoneOwner.uid !== uid) {
      if (!(await isDisposablePhoneUser(phoneOwner.uid))) {
        throw new HttpsError(
          "already-exists",
          "This mobile number is already registered to another account."
        );
      }
    } else {
      try {
        await admin.auth().updateUser(uid, { phoneNumber });
      } catch (err: any) {
        console.error("[syncVerifiedPhone] Could not attach phone to auth user:", err);
        throw new HttpsError(
          "failed-precondition",
          "The code was verified, but this number could not be attached. Please try again."
        );
      }
    }

    const digits = phoneNumber.replace(/\D/g, "").slice(-10);
    const payload = { phoneNumber, phoneDigits: digits };
    await db.collection("candidates").doc(uid).set(payload, { merge: true });
    await db.collection("users").doc(uid).set(payload, { merge: true });
    return { success: true, phoneNumber };
  }
);

export const loginWithPhoneOtp = onCall(
  { region: "us-central1" },
  async (request) => {
    const data = request.data;
    const idToken = (data?.idToken || "").trim();

    if (!idToken) {
      throw new HttpsError("invalid-argument", "ID Token is required.");
    }

    try {
      // 1. Verify the ID token using Admin SDK (decodes RS256 token)
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      const tempUid = decodedToken.uid;
      const phoneNumber = decodedToken.phone_number;

      if (!phoneNumber) {
        throw new HttpsError("invalid-argument", "ID token does not contain a verified phone number.");
      }

      const normalizedPhone = normalizeStoredPhone(phoneNumber);
      console.log(`[loginWithPhoneOtp] Verified phone number: ${normalizedPhone} for session UID: ${tempUid}`);

      const matches = await findCandidateIdsForPhone(normalizedPhone);
      const primaryUid = await choosePrimaryCandidate(matches);

      const phoneOnlySession =
        !primaryUid || (primaryUid === tempUid && !(await authUserHasEmail(tempUid)));
      if (phoneOnlySession) {
        throw new HttpsError(
          "not-found",
          "No account uses this mobile number yet. Create an account with email, then add this number in Edit Profile."
        );
      }

      const userDoc = await db.collection("users").doc(primaryUid).get();
      const candidateDoc = await db.collection("candidates").doc(primaryUid).get();
      const role = userDoc.data()?.role;
      if (role && role !== "candidate" && !candidateDoc.exists) {
        throw new HttpsError(
          "permission-denied",
          "This mobile number belongs to an account that cannot be used in the candidate app."
        );
      }

      const digits = normalizedPhone.replace(/\D/g, "").slice(-10);
      if (candidateDoc.exists) {
        await candidateDoc.ref.set(
          { phoneNumber: normalizedPhone, phoneDigits: digits },
          { merge: true }
        );
      }
      if (userDoc.exists) {
        await userDoc.ref.set(
          { phoneNumber: normalizedPhone, phoneDigits: digits },
          { merge: true }
        );
      }

      const customToken = await admin.auth().createCustomToken(primaryUid, {
        loginProvider: "phone_otp",
      });

      console.log(`[loginWithPhoneOtp] Custom token issued for ${primaryUid}`);

      return {
        success: true,
        customToken,
        uid: primaryUid,
      };
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("[loginWithPhoneOtp] Error verifying phone OTP token:", error);
      throw new HttpsError("internal", error.message || "Failed to process phone OTP login.");
    }
  }
);

export const getCareerReadinessGuidance = onCall(
  { secrets: ["GEMINI_API_KEY"], region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const userId = request.auth.uid;

    try {
      let candidateDoc = await db.collection("candidates").doc(userId).get();
      if (!candidateDoc.exists) {
        candidateDoc = await db.collection("users").doc(userId).get();
      }
      if (!candidateDoc.exists) {
        throw new HttpsError("permission-denied", "Candidate profile not found or unauthorized.");
      }

      const data = request.data || {};
      const skillScores: Record<string, number> = data.skillScores || {};
      const targetJobTitle: string = (data.targetJobTitle || "").trim();
      const targetJobSkills: string[] = Array.isArray(data.targetJobSkills) ? data.targetJobSkills : [];

      const apiKey = (process.env.GEMINI_API_KEY || "").trim();
      if (!apiKey) {
        throw new HttpsError("failed-precondition", "AI service is currently misconfigured.");
      }

      const candidateModels = [
        process.env.GEMINI_MODEL,
        "gemini-3.8-flash",
        "gemini-1.5-flash",
        "gemini-2.0-flash",
      ].filter((m, i, self) => m && m.trim().length > 0 && self.indexOf(m) === i) as string[];

      const skillsFormatted = Object.entries(skillScores)
        .map(([skill, score]) => `- ${skill}: ${score}%`)
        .join("\n");

      let prompt = `Analyze the candidate's technical skill assessment scores and provide supportive, practical, step-by-step career readiness guidance.

Candidate Skill Scores:
${skillsFormatted || "No skills assessed yet."}`;

      if (targetJobTitle && targetJobSkills.length > 0) {
        prompt += `\n\nTarget Job Role: "${targetJobTitle}"
Required Job Skills: ${targetJobSkills.join(", ")}`;
      }

      prompt += `\n\nIMPORTANT RULES:
1. Use supportive, encouraging tone. DO NOT use harsh labels like "failed", "poor", "weak", or "bad".
2. Focus on practical improvement steps, key concepts to review, and clear actionable roadmap.
3. The response MUST be a valid raw JSON object matching this structure:
{
  "overallSummary": "A concise supportive summary of current skill readiness and main recommendation.",
  "skillsToStrengthen": [
    {
      "skill": "Skill Name",
      "score": 45,
      "guidance": "Short encouraging 1-line summary for this skill.",
      "roadmapSteps": [
        {
          "stepNumber": 1,
          "title": "Build the basics",
          "description": "Short focus summary",
          "actionHeader": "LEARN",
          "actionItems": [
            "Data modeling concepts",
            "Relationships & schema basics",
            "Basic DAX measures (CALCULATE, RELATED)"
          ]
        },
        {
          "stepNumber": 2,
          "title": "Practice",
          "description": "Short focus summary",
          "actionHeader": "DO",
          "actionItems": [
            "Create a multi-page interactive dashboard",
            "Use open-source datasets for hands-on practice"
          ]
        },
        {
          "stepNumber": 3,
          "title": "Go deeper",
          "description": "Short focus summary",
          "actionHeader": "FOCUS ON",
          "actionItems": [
            "Power Query data cleansing",
            "Schema optimization & query tuning"
          ]
        },
        {
          "stepNumber": 4,
          "title": "Check your progress",
          "description": "Short focus summary",
          "actionHeader": "CHECK YOUR PROGRESS",
          "actionItems": [
            "Retake assessment to verify score improvement"
          ]
        }
      ]
    }
  ],
  "jobMatchAdvice": "Specific advice on preparing for the target job role (or empty string if no target job)."
}
Do NOT wrap output in markdown codeblocks. Return pure valid JSON.`;

      let responseText = "";
      let lastErrorText = "";
      let hasExplicitDailyQuotaExhaustion = false;
      let hasServiceUnavailable = false;

      const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

      for (const modelName of candidateModels) {
        const maxModelRetries = 2;

        for (let attempt = 0; attempt <= maxModelRetries; attempt++) {
          try {
            const response = await fetch(
              `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
              {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  contents: [{ parts: [{ text: prompt }] }],
                  generationConfig: {
                    temperature: 0.6,
                    responseMimeType: "application/json",
                  },
                }),
              }
            );

            let isBlockedResponse = false;

            if (response.ok) {
              const responseData: any = await response.json();
              const candidate = responseData?.candidates?.[0];
              const finishReason = candidate?.finishReason;
              const blockReason = responseData?.promptFeedback?.blockReason;

              if (blockReason || (finishReason && finishReason !== "STOP" && finishReason !== "MAX_TOKENS")) {
                console.warn(
                  `[getCareerReadinessGuidance] Model ${modelName} returned HTTP 200 with blocked/non-STOP status: blockReason=${blockReason}, finishReason=${finishReason}`
                );
                lastErrorText = `HTTP 200 response blocked (blockReason: ${blockReason || "none"}, finishReason: ${finishReason || "none"})`;
                isBlockedResponse = true;
              } else {
                const text = candidate?.content?.parts?.[0]?.text;
                if (text && typeof text === "string" && text.trim().length > 0) {
                  let cleanJson = text.trim();
                  cleanJson = cleanJson
                    .replace(/^```json\s*/i, "")
                    .replace(/^```\s*/, "")
                    .replace(/\s*```$/, "")
                    .trim();

                  const firstBrace = cleanJson.indexOf("{");
                  const lastBrace = cleanJson.lastIndexOf("}");
                  if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
                    cleanJson = cleanJson.substring(firstBrace, lastBrace + 1);
                  }

                  try {
                    const parsed = JSON.parse(cleanJson);
                    if (
                      parsed &&
                      typeof parsed === "object" &&
                      typeof parsed.overallSummary === "string" &&
                      Array.isArray(parsed.skillsToStrengthen)
                    ) {
                      responseText = cleanJson;
                      console.log(`[getCareerReadinessGuidance] Successfully generated & validated content using model: ${modelName}`);
                      break;
                    } else {
                      console.warn(`[getCareerReadinessGuidance] Model ${modelName} returned JSON missing required schema fields.`);
                      lastErrorText = "HTTP 200 returned JSON missing required schema fields";
                    }
                  } catch (jsonErr: any) {
                    console.warn(
                      `[getCareerReadinessGuidance] Model ${modelName} returned invalid/truncated JSON (finishReason: ${finishReason}): ${jsonErr.message}`
                    );
                    lastErrorText = `HTTP 200 returned invalid/truncated JSON (finishReason: ${finishReason || "unknown"})`;
                  }
                } else {
                  console.warn(
                    `[getCareerReadinessGuidance] Model ${modelName} returned HTTP 200 but text content was empty or missing.`
                  );
                  lastErrorText = "HTTP 200 returned empty text payload";
                }
              }
            } else {
              lastErrorText = await response.text().catch(() => "");
            }

            const status = response.status;
            console.warn(
              `[getCareerReadinessGuidance] Model ${modelName} attempt ${attempt + 1} status ${status}: ${lastErrorText.slice(0, 200)}`
            );

            if (status === 503 || lastErrorText.includes("503") || lastErrorText.includes("UNAVAILABLE")) {
              hasServiceUnavailable = true;
            }

            // Check specifically for explicit Daily Quota Exhaustion based on quota ID / metric
            let isExplicitDailyQuotaExhausted = false;
            let retryDelayMs = 0;

            if (status === 429) {
              try {
                const errObj = JSON.parse(lastErrorText);
                const errDetails = errObj?.error?.details || [];
                const quotaFailure = errDetails.find((d: any) => d["@type"]?.includes("QuotaFailure"));
                const violations: any[] = quotaFailure?.violations || [];
                const dailyViolation = violations.find(
                  (v) =>
                    v?.quotaId?.includes("GenerateRequestsPerDay") ||
                    v?.quotaId?.includes("PerDay") ||
                    v?.quotaMetric?.includes("generate_content_free_tier_requests")
                );

                if (
                  dailyViolation ||
                  lastErrorText.includes("GenerateRequestsPerDayPerProjectPerModel-FreeTier") ||
                  lastErrorText.includes("GenerateRequestsPerDay")
                ) {
                  isExplicitDailyQuotaExhausted = true;
                  hasExplicitDailyQuotaExhaustion = true;
                }

                const retryInfo = errDetails.find((d: any) => d["@type"]?.includes("RetryInfo"));
                if (retryInfo?.retryDelay) {
                  const seconds = parseInt(retryInfo.retryDelay.replace("s", ""), 10);
                  if (!isNaN(seconds) && seconds > 0) {
                    retryDelayMs = seconds * 1000;
                  }
                }
              } catch (_) {
                if (lastErrorText.includes("GenerateRequestsPerDay")) {
                  isExplicitDailyQuotaExhausted = true;
                  hasExplicitDailyQuotaExhaustion = true;
                }
              }

              const retryAfterHeader = response.headers.get("retry-after");
              if (retryAfterHeader) {
                const seconds = parseInt(retryAfterHeader, 10);
                if (!isNaN(seconds) && seconds > 0) {
                  retryDelayMs = seconds * 1000;
                }
              }
            }

            // If explicit daily quota is exhausted for this model, do not retry this model. Fall through to try next candidate model.
            if (status === 429 && isExplicitDailyQuotaExhausted) {
              console.warn(
                `[getCareerReadinessGuidance] Model ${modelName} Explicit Daily Quota Exhausted (GenerateRequestsPerDay). Skipping retries for this model.`
              );
              break;
            }

            // If response was blocked by content filters, retrying same prompt on same model will not help; fall through to next model
            if (response.ok && isBlockedResponse) {
              console.warn(`[getCareerReadinessGuidance] Model ${modelName} response was blocked. Skipping retries for this model.`);
              break;
            }

            // If transient rate limit (429 RPM/TPM), server overload (503), or invalid text 200, apply bounded backoff retry on same model
            const isTransientError = status === 429 || status === 503 || (response.ok && !responseText);
            if (isTransientError && attempt < maxModelRetries) {
              const backoffMs = retryDelayMs > 0 ? Math.min(retryDelayMs, 5000) : Math.pow(2, attempt) * 1000 + Math.floor(Math.random() * 500);
              console.log(`[getCareerReadinessGuidance] Retrying model ${modelName} in ${backoffMs}ms (attempt ${attempt + 1}/${maxModelRetries})...`);
              await delay(backoffMs);
              continue;
            }

            break;
          } catch (e: any) {
            lastErrorText = e.message || String(e);
            console.warn(`[getCareerReadinessGuidance] Exception trying model ${modelName} attempt ${attempt + 1}:`, lastErrorText);
            if (attempt < maxModelRetries) {
              await delay(1000 * (attempt + 1));
            }
          }
        }

        if (responseText) {
          break;
        }
      }

      if (!responseText) {
        console.error("[getCareerReadinessGuidance] All candidate Gemini models failed. Last error:", lastErrorText);
        if (
          hasExplicitDailyQuotaExhaustion ||
          lastErrorText.includes("RESOURCE_EXHAUSTED") ||
          lastErrorText.includes("Quota exceeded")
        ) {
          throw new HttpsError(
            "resource-exhausted",
            "The AI service daily usage limit has been reached. Please try again later or contact support."
          );
        }
        if (hasServiceUnavailable || lastErrorText.includes("UNAVAILABLE") || lastErrorText.includes("503")) {
          throw new HttpsError(
            "unavailable",
            "The AI service is currently experiencing high demand. Please try again in a few moments."
          );
        }
        throw new HttpsError("internal", "AI failed to generate guidance.");
      }

      let cleanJson = responseText.trim();
      cleanJson = cleanJson
        .replace(/^```json\s*/i, "")
        .replace(/^```\s*/, "")
        .replace(/\s*```$/, "")
        .trim();

      const firstBrace = cleanJson.indexOf("{");
      const lastBrace = cleanJson.lastIndexOf("}");
      if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
        cleanJson = cleanJson.substring(firstBrace, lastBrace + 1);
      }

      let parsedData: any;
      try {
        parsedData = JSON.parse(cleanJson);
      } catch (e: any) {
        console.error("[getCareerReadinessGuidance] JSON parse error. Raw text:", responseText, "Error:", e);
        throw new HttpsError("internal", "AI generated a malformed response format. Please try again.");
      }

      return parsedData;
    } catch (error: any) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("[getCareerReadinessGuidance] Error:", error);
      throw new HttpsError("internal", "An error occurred while generating guidance.");
    }
  }
);


