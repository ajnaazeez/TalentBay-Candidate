"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyEmailOtp = exports.sendEmailOtp = exports.verifyRazorpayPayment = exports.createRazorpayOrder = exports.deleteUserAccount = exports.getRelatedSkills = exports.generateAssessmentQuestions = exports.enhanceText = exports.bulkPostJobs = exports.generateJobDescription = exports.onMessageCreated = void 0;
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
async function sendOtpEmail(toEmail, otpCode) {
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
    }
    catch (err) {
        console.error(`[sendOtpEmail] Error sending email to ${toEmail}:`, err);
        return false;
    }
}
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
    var _a, _b, _c, _d, _e, _f;
    // 1. Authentication Check
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const userId = request.auth.uid;
    try {
        // 2. Authorization Check (Candidate verification)
        const candidateDoc = await db.collection("candidates").doc(userId).get();
        const userDoc = await db.collection("users").doc(userId).get();
        const isCandidate = candidateDoc.exists || (userDoc.exists && ((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.role) === "candidate");
        if (!isCandidate) {
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
        // 4. Secure API Key Retrieval
        const apiKey = (process.env.GEMINI_API_KEY || "").trim();
        if (!apiKey) {
            console.error("GEMINI_API_KEY secret is not configured on the backend.");
            throw new https_1.HttpsError("failed-precondition", "AI service is currently misconfigured.");
        }
        // 5. Model Selection & REST Invocation with Auto-Fallback
        const candidateModels = [
            process.env.GEMINI_MODEL,
            "gemini-3.8-flash",
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
        ].filter((m, i, self) => m && m.trim().length > 0 && self.indexOf(m) === i);
        let lastErrorText = "";
        for (const modelName of candidateModels) {
            try {
                const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`, {
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
                if (response.ok) {
                    const responseData = await response.json();
                    const responseText = (_f = (_e = (_d = (_c = (_b = responseData === null || responseData === void 0 ? void 0 : responseData.candidates) === null || _b === void 0 ? void 0 : _b[0]) === null || _c === void 0 ? void 0 : _c.content) === null || _d === void 0 ? void 0 : _d.parts) === null || _e === void 0 ? void 0 : _e[0]) === null || _f === void 0 ? void 0 : _f.text;
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
                }
                else {
                    lastErrorText = await response.text().catch(() => "");
                    console.warn(`[enhanceText] Model ${modelName} returned status ${response.status}: ${lastErrorText}`);
                }
            }
            catch (err) {
                console.warn(`[enhanceText] Exception trying model ${modelName}:`, err);
            }
        }
        console.error("[enhanceText] All candidate Gemini models failed. Last error:", lastErrorText);
        throw new https_1.HttpsError("internal", "Failed to generate enhanced text from AI service.");
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
        const model = process.env.GEMINI_MODEL || "gemini-1.5-flash";
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
        const model = process.env.GEMINI_MODEL || "gemini-1.5-flash";
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
exports.deleteUserAccount = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    var _a, _b;
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
        throw new https_1.HttpsError("unauthenticated", "You must be signed in to delete your account.");
    }
    const userId = request.auth.uid;
    console.log(`[deleteUserAccount] Initiating permanent deletion for UID: ${userId}`);
    try {
        // 2. Fetch recruiter profile to inspect company and personal assets
        const recruiterRef = db.collection("recruiters").doc(userId);
        const recruiterDoc = await recruiterRef.get();
        const recruiterData = recruiterDoc.exists ? recruiterDoc.data() : null;
        const companyId = recruiterData === null || recruiterData === void 0 ? void 0 : recruiterData.companyId;
        const recruiterPhotoUrl = recruiterData === null || recruiterData === void 0 ? void 0 : recruiterData.photoUrl;
        // 3. Handle Company Data with ownership safety
        if (companyId) {
            const companyRef = db.collection("companies").doc(companyId);
            const companyDoc = await companyRef.get();
            if (companyDoc.exists) {
                const companyData = companyDoc.data();
                const createdBy = (_a = companyData === null || companyData === void 0 ? void 0 : companyData.meta) === null || _a === void 0 ? void 0 : _a.createdBy;
                // Check if other active recruiters belong to this company
                const otherRecruiters = await db
                    .collection("recruiters")
                    .where("companyId", "==", companyId)
                    .get();
                const hasOtherRecruiters = otherRecruiters.docs.some((doc) => doc.id !== userId);
                if (!hasOtherRecruiters && (createdBy === userId || !createdBy)) {
                    // Delete company logo from Storage if hosted in bucket
                    const logoUrl = ((_b = companyData === null || companyData === void 0 ? void 0 : companyData.profile) === null || _b === void 0 ? void 0 : _b.logoUrl) || (companyData === null || companyData === void 0 ? void 0 : companyData.logoUrl);
                    if (logoUrl && typeof logoUrl === "string") {
                        try {
                            const bucket = admin.storage().bucket();
                            const matches = logoUrl.match(/\/o\/([^?]+)/);
                            if (matches && matches[1]) {
                                const decodedPath = decodeURIComponent(matches[1]);
                                await bucket
                                    .file(decodedPath)
                                    .delete()
                                    .catch((e) => {
                                    console.warn(`[deleteUserAccount] Storage delete company logo warning: ${e.message}`);
                                });
                            }
                        }
                        catch (storageErr) {
                            console.warn(`[deleteUserAccount] Could not delete company logo from storage: ${storageErr.message}`);
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
                        .catch((e) => {
                        console.warn(`[deleteUserAccount] Storage delete recruiter photo warning: ${e.message}`);
                    });
                }
            }
            catch (storageErr) {
                console.warn(`[deleteUserAccount] Could not delete recruiter photo from storage: ${storageErr.message}`);
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
        }
        catch (authErr) {
            if (authErr.code !== "auth/user-not-found") {
                console.error(`[deleteUserAccount] Error deleting Firebase Auth user:`, authErr);
                throw new https_1.HttpsError("internal", "Failed to delete authentication user record.");
            }
        }
        return {
            success: true,
            message: "User account and associated recruiter data permanently deleted.",
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        console.error("[deleteUserAccount] Unhandled error:", error);
        throw new https_1.HttpsError("internal", "An error occurred while deleting your account. Please try again.");
    }
});
// ==========================================
// Razorpay Subscription Configuration
// ==========================================
const SUBSCRIPTION_PLANS = [
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
];
/**
 * createRazorpayOrder (us-central1)
 * Creates a server-side order with Razorpay.
 */
exports.createRazorpayOrder = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
        throw new https_1.HttpsError("unauthenticated", "You must be signed in to create an order.");
    }
    const uid = request.auth.uid;
    const data = request.data;
    const planId = data === null || data === void 0 ? void 0 : data.planId;
    if (!planId) {
        throw new https_1.HttpsError("invalid-argument", "Plan ID is required.");
    }
    const plan = SUBSCRIPTION_PLANS.find((p) => p.id === planId);
    if (!plan) {
        throw new https_1.HttpsError("not-found", `Invalid subscription plan: ${planId}`);
    }
    // 2. Trial Plan Eligibility Verification
    if (plan.id === "trial_60_days_1_rupee") {
        const recruiterDoc = await db.collection("recruiters").doc(uid).get();
        if (recruiterDoc.exists) {
            const rData = recruiterDoc.data();
            if ((rData === null || rData === void 0 ? void 0 : rData.subscriptionPlanId) || (rData === null || rData === void 0 ? void 0 : rData.subscriptionTier)) {
                throw new https_1.HttpsError("failed-precondition", "The introductory trial offer is only available for first-time recruiter accounts.");
            }
        }
    }
    // 3. Razorpay Secrets Validation
    const keyId = process.env.RAZORPAY_KEY_ID || "rzp_live_TIywUmGVFfdXXf";
    const keySecret = process.env.RAZORPAY_KEY_SECRET || "WWjcLIcItrw39bakd5v1aRAX";
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
            throw new https_1.HttpsError("internal", `Payment gateway order creation failed: ${errText}`);
        }
        const orderData = (await response.json());
        console.log(`[createRazorpayOrder] Created order ${orderData.id} for user ${uid}, amount ${orderData.amount} ${orderData.currency}`);
        return {
            orderId: orderData.id,
            id: orderData.id,
            amount: orderData.amount,
            currency: orderData.currency,
        };
    }
    catch (err) {
        if (err instanceof https_1.HttpsError) {
            throw err;
        }
        console.error("[createRazorpayOrder] Unexpected error creating order:", err);
        throw new https_1.HttpsError("internal", "An error occurred while creating your payment order.");
    }
});
/**
 * verifyRazorpayPayment (us-central1)
 * Verifies Razorpay payment signature, verifies payment status with Razorpay API,
 * records payment receipt idempotently, and activates recruiter subscription using Firebase Admin SDK.
 */
exports.verifyRazorpayPayment = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    var _a, _b;
    // 1. Strict Authentication Check
    if (!request.auth || !request.auth.uid) {
        throw new https_1.HttpsError("unauthenticated", "You must be signed in to verify payment.");
    }
    const uid = request.auth.uid;
    const data = request.data;
    const paymentId = (_a = data === null || data === void 0 ? void 0 : data.paymentId) === null || _a === void 0 ? void 0 : _a.trim();
    if (!paymentId) {
        throw new https_1.HttpsError("invalid-argument", "Payment ID is required.");
    }
    const planId = data === null || data === void 0 ? void 0 : data.planId;
    if (!planId) {
        throw new https_1.HttpsError("invalid-argument", "Plan ID is required.");
    }
    const plan = SUBSCRIPTION_PLANS.find((p) => p.id === planId);
    if (!plan) {
        throw new https_1.HttpsError("not-found", `Invalid subscription plan: ${planId}`);
    }
    // 2. Razorpay Secrets Validation
    const keyId = process.env.RAZORPAY_KEY_ID || "rzp_live_TIywUmGVFfdXXf";
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keySecret) {
        console.error("[verifyRazorpayPayment] RAZORPAY_KEY_SECRET is not configured.");
        throw new https_1.HttpsError("failed-precondition", "RAZORPAY_KEY_SECRET is not configured.");
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
            throw new https_1.HttpsError("invalid-argument", "Payment signature verification failed.");
        }
        console.log(`[verifyRazorpayPayment] Signature verified successfully for payment ${paymentId}`);
    }
    // 4. Fetch and Verify Payment Details from Razorpay API
    const authHeader = "Basic " + Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    let rzpPayment = null;
    try {
        const rzpRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
            method: "GET",
            headers: { Authorization: authHeader },
        });
        if (!rzpRes.ok) {
            const errText = await rzpRes.text();
            console.error("[verifyRazorpayPayment] Razorpay fetch payment error:", rzpRes.status, errText);
            throw new https_1.HttpsError("not-found", "Payment record not found on payment gateway.");
        }
        rzpPayment = await rzpRes.json();
    }
    catch (fetchErr) {
        if (fetchErr instanceof https_1.HttpsError)
            throw fetchErr;
        console.error("[verifyRazorpayPayment] Error fetching payment from Razorpay:", fetchErr);
        throw new https_1.HttpsError("internal", "Could not verify payment with payment gateway.");
    }
    // 5. Verify Amount, Currency, and Status
    if (rzpPayment.currency !== "INR") {
        throw new https_1.HttpsError("invalid-argument", `Invalid payment currency: ${rzpPayment.currency}`);
    }
    if (Number(rzpPayment.amount) !== plan.amountPaise) {
        throw new https_1.HttpsError("invalid-argument", `Payment amount mismatch. Expected: ₹${plan.price} (${plan.amountPaise} paise), Found: ${rzpPayment.amount} paise.`);
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
        }
        catch (capErr) {
            console.warn("[verifyRazorpayPayment] Capture attempt warning:", capErr);
        }
    }
    if (rzpPayment.status !== "captured") {
        throw new https_1.HttpsError("failed-precondition", `Payment is not yet captured (Status: ${rzpPayment.status}). Please wait or complete payment.`);
    }
    // 6. Idempotency Check on /recruiters/{uid}/payments/{paymentId}
    const paymentDocRef = db
        .collection("recruiters")
        .doc(uid)
        .collection("payments")
        .doc(paymentId);
    const existingPayment = await paymentDocRef.get();
    if (existingPayment.exists && ((_b = existingPayment.data()) === null || _b === void 0 ? void 0 : _b.status) === "success") {
        console.log(`[verifyRazorpayPayment] Payment ${paymentId} already processed idempotently.`);
        return {
            success: true,
            verified: true,
            alreadyProcessed: true,
            message: "Payment has already been verified and activated.",
        };
    }
    // 7. Calculate Expiry Date & Perform Admin SDK Writes
    const now = new Date();
    const expiryDate = new Date(now.getTime() + plan.durationDays * 24 * 60 * 60 * 1000);
    const expiryTimestamp = admin.firestore.Timestamp.fromDate(expiryDate);
    const serverTime = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();
    // 7a. Write payment receipt
    batch.set(paymentDocRef, {
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
    }, { merge: true });
    // 7b. Update canonical recruiter profile
    const recruiterRef = db.collection("recruiters").doc(uid);
    batch.set(recruiterRef, {
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
    }, { merge: true });
    // 7c. Update user role document
    const userRef = db.collection("users").doc(uid);
    batch.set(userRef, {
        isSubscribed: true,
        subscriptionPlanId: plan.id,
        subscriptionExpiry: expiryTimestamp,
        updatedAt: serverTime,
    }, { merge: true });
    await batch.commit();
    console.log(`[verifyRazorpayPayment] Successfully activated subscription for user ${uid}, plan ${plan.id}, expiry ${expiryDate.toISOString()}`);
    return {
        success: true,
        verified: true,
        expiryDate: expiryDate.toISOString(),
        planId: plan.id,
        paymentId: paymentId,
    };
});
exports.sendEmailOtp = (0, https_1.onCall)({ region: "us-central1", secrets: ["SMTP_USER", "SMTP_PASS"] }, async (request) => {
    const data = request.data;
    const email = ((data === null || data === void 0 ? void 0 : data.email) || "").trim().toLowerCase();
    if (!email || !email.includes("@")) {
        throw new https_1.HttpsError("invalid-argument", "A valid email address is required.");
    }
    // Check if email already registered in auth or users collection
    try {
        const existingUser = await admin.auth().getUserByEmail(email).catch(() => null);
        if (existingUser) {
            throw new https_1.HttpsError("already-exists", "An account with this email address already exists. Please log in.");
        }
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
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
        throw new https_1.HttpsError("internal", "Unable to send verification email. Please contact support or try again later.");
    }
    return {
        success: true,
        message: "OTP sent successfully to email.",
    };
});
exports.verifyEmailOtp = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    const data = request.data;
    const email = ((data === null || data === void 0 ? void 0 : data.email) || "").trim().toLowerCase();
    const otp = ((data === null || data === void 0 ? void 0 : data.otp) || "").trim();
    if (!email || !otp || otp.length !== 6) {
        throw new https_1.HttpsError("invalid-argument", "Valid email and 6-digit OTP are required.");
    }
    const otpDocRef = db.collection("email_otps").doc(email);
    const otpDoc = await otpDocRef.get();
    if (!otpDoc.exists) {
        throw new https_1.HttpsError("not-found", "No OTP code request found for this email. Please request a new code.");
    }
    const otpData = otpDoc.data();
    const expiresAt = otpData.expiresAt.toDate();
    if (Date.now() > expiresAt.getTime()) {
        await otpDocRef.delete();
        throw new https_1.HttpsError("deadline-exceeded", "OTP has expired. Please request a new code.");
    }
    if (otpData.attempts >= 5) {
        await otpDocRef.delete();
        throw new https_1.HttpsError("resource-exhausted", "Too many failed attempts. Please request a new OTP code.");
    }
    const inputHash = crypto.createHash("sha256").update(`${email}:${otp}`).digest("hex");
    if (inputHash !== otpData.otpHash) {
        await otpDocRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
        throw new https_1.HttpsError("invalid-argument", "Invalid OTP code. Please check and try again.");
    }
    await otpDocRef.delete();
    return {
        success: true,
        verified: true,
        message: "Email successfully verified.",
    };
});
//# sourceMappingURL=index.js.map