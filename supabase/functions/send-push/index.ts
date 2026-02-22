// supabase/functions/send-push/index.ts
//
// Supabase Edge Function template for sending APNs push notifications.
//
// This function is designed to be triggered by Supabase Database Webhooks
// on table inserts (assignments, grades, messages, announcements).
//
// -----------------------------------------------------------------------
// DEPLOYMENT:
//   supabase functions deploy send-push --no-verify-jwt
//
// ENVIRONMENT VARIABLES (set via Supabase dashboard or CLI):
//   APNS_KEY_ID        - Your Apple Push Notification key ID
//   APNS_TEAM_ID       - Your Apple Developer Team ID
//   APNS_PRIVATE_KEY   - The .p8 private key contents (base64 encoded)
//   APNS_TOPIC          - Your app bundle identifier (e.g. com.wolfwhale.lms)
//   APNS_ENVIRONMENT   - "production" or "development"
//   SUPABASE_URL       - Auto-injected by Supabase
//   SUPABASE_SERVICE_ROLE_KEY - Auto-injected by Supabase
// -----------------------------------------------------------------------

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: Record<string, unknown>;
  old_record: Record<string, unknown> | null;
}

interface DeviceToken {
  user_id: string;
  token: string;
  platform: string;
}

interface APNsPayload {
  aps: {
    alert: {
      title: string;
      body: string;
    };
    sound: string;
    badge?: number;
    "content-available"?: number;
    "mutable-content"?: number;
    category?: string;
  };
  // Custom keys for deep linking
  type?: string;
  assignmentId?: string;
  courseId?: string;
  conversationId?: string;
  gradeId?: string;
}

// ---------------------------------------------------------------------------
// Supabase Client (service role for reading device_tokens)
// ---------------------------------------------------------------------------

function getSupabaseClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, key);
}

// ---------------------------------------------------------------------------
// APNs JWT Generation
// ---------------------------------------------------------------------------

// TODO: Implement APNs JWT token generation using the ES256 algorithm.
//
// Apple requires a short-lived JWT signed with your .p8 key:
//   Header:  { alg: "ES256", kid: APNS_KEY_ID }
//   Payload: { iss: APNS_TEAM_ID, iat: <unix timestamp> }
//
// You can use a library like `jose` for Deno:
//   import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";
//
// Cache the token for ~50 minutes (Apple tokens are valid for 1 hour).

let cachedToken: string | null = null;
let cachedTokenTimestamp = 0;

async function getAPNsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Reuse cached token if it's less than 50 minutes old
  if (cachedToken && now - cachedTokenTimestamp < 3000) {
    return cachedToken;
  }

  // TODO: Replace this stub with real JWT signing.
  //
  // Example with jose:
  //
  // const keyId = Deno.env.get("APNS_KEY_ID")!;
  // const teamId = Deno.env.get("APNS_TEAM_ID")!;
  // const privateKeyBase64 = Deno.env.get("APNS_PRIVATE_KEY")!;
  // const privateKeyPem = atob(privateKeyBase64);
  //
  // const ecPrivateKey = await jose.importPKCS8(privateKeyPem, "ES256");
  // const jwt = await new jose.SignJWT({ iss: teamId, iat: now })
  //   .setProtectedHeader({ alg: "ES256", kid: keyId })
  //   .sign(ecPrivateKey);
  //
  // cachedToken = jwt;
  // cachedTokenTimestamp = now;
  // return jwt;

  throw new Error(
    "APNs JWT generation not implemented. See TODO comments above."
  );
}

// ---------------------------------------------------------------------------
// Send Push via APNs HTTP/2
// ---------------------------------------------------------------------------

async function sendPushNotification(
  deviceToken: string,
  payload: APNsPayload
): Promise<boolean> {
  const topic = Deno.env.get("APNS_TOPIC") ?? "com.wolfwhale.lms";
  const environment = Deno.env.get("APNS_ENVIRONMENT") ?? "development";

  const host =
    environment === "production"
      ? "https://api.push.apple.com"
      : "https://api.sandbox.push.apple.com";

  const url = `${host}/3/device/${deviceToken}`;

  try {
    const jwt = await getAPNsJWT();

    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `bearer ${jwt}`,
        "apns-topic": topic,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(
        `APNs error for token ${deviceToken.substring(0, 8)}...: ${response.status} ${errorBody}`
      );
      return false;
    }

    return true;
  } catch (err) {
    console.error(`Failed to send push to ${deviceToken.substring(0, 8)}...:`, err);
    return false;
  }
}

// ---------------------------------------------------------------------------
// Fetch Device Tokens for Users
// ---------------------------------------------------------------------------

async function getDeviceTokensForUsers(
  userIds: string[]
): Promise<DeviceToken[]> {
  if (userIds.length === 0) return [];

  const supabase = getSupabaseClient();

  const { data, error } = await supabase
    .from("device_tokens")
    .select("user_id, token, platform")
    .in("user_id", userIds)
    .eq("platform", "ios");

  if (error) {
    console.error("Failed to fetch device tokens:", error);
    return [];
  }

  return (data as DeviceToken[]) ?? [];
}

async function getDeviceTokensForSchool(
  schoolId: string
): Promise<DeviceToken[]> {
  const supabase = getSupabaseClient();

  // Get all users in the school, then their tokens
  const { data: users, error: usersError } = await supabase
    .from("profiles")
    .select("id")
    .eq("school_id", schoolId);

  if (usersError || !users) {
    console.error("Failed to fetch school users:", usersError);
    return [];
  }

  const userIds = users.map((u: { id: string }) => u.id);
  return getDeviceTokensForUsers(userIds);
}

async function getEnrolledStudentTokens(
  courseId: string
): Promise<DeviceToken[]> {
  const supabase = getSupabaseClient();

  // Get students enrolled in the course
  const { data: enrollments, error } = await supabase
    .from("enrollments")
    .select("student_id")
    .eq("course_id", courseId)
    .eq("status", "active");

  if (error || !enrollments) {
    console.error("Failed to fetch enrollments:", error);
    return [];
  }

  const studentIds = enrollments.map(
    (e: { student_id: string }) => e.student_id
  );
  return getDeviceTokensForUsers(studentIds);
}

// ---------------------------------------------------------------------------
// Event Handlers
// ---------------------------------------------------------------------------

// TODO: Wire these handlers to Supabase Database Webhooks.
//
// In the Supabase dashboard (Database > Webhooks), create webhooks that
// POST to this edge function URL when rows are inserted in the relevant
// tables. Each webhook should include the full row in the payload.

/**
 * Triggered when a new assignment is created.
 * Sends a push notification to all students enrolled in the course.
 */
async function onAssignmentCreated(
  record: Record<string, unknown>
): Promise<void> {
  const courseId = record.course_id as string;
  const title = record.title as string;
  const dueDate = record.due_date as string | null;

  // Fetch course name for the notification
  const supabase = getSupabaseClient();
  const { data: course } = await supabase
    .from("courses")
    .select("name")
    .eq("id", courseId)
    .single();

  const courseName = course?.name ?? "Your Course";

  const tokens = await getEnrolledStudentTokens(courseId);

  const dueDateStr = dueDate
    ? ` Due: ${new Date(dueDate).toLocaleDateString()}`
    : "";

  const payload: APNsPayload = {
    aps: {
      alert: {
        title: `New Assignment: ${courseName}`,
        body: `"${title}" has been posted.${dueDateStr}`,
      },
      sound: "default",
      category: "ASSIGNMENT_REMINDER",
    },
    type: "assignment",
    assignmentId: record.id as string,
    courseId: courseId,
  };

  const results = await Promise.allSettled(
    tokens.map((t) => sendPushNotification(t.token, payload))
  );

  const sent = results.filter(
    (r) => r.status === "fulfilled" && r.value
  ).length;
  console.log(
    `[on_assignment_created] Sent ${sent}/${tokens.length} notifications for assignment "${title}"`
  );
}

/**
 * Triggered when a grade is entered/updated.
 * Sends a push notification to the specific student.
 */
async function onGradeEntered(
  record: Record<string, unknown>
): Promise<void> {
  const studentId = record.student_id as string;
  const assignmentId = record.assignment_id as string;
  const pointsEarned = record.points_earned as number | null;
  const maxPoints = record.max_points as number | null;

  // Fetch assignment title for the notification
  const supabase = getSupabaseClient();
  const { data: assignment } = await supabase
    .from("assignments")
    .select("title, course_id")
    .eq("id", assignmentId)
    .single();

  const assignmentTitle = assignment?.title ?? "Assignment";

  let gradeStr = "Your grade has been posted";
  if (pointsEarned != null && maxPoints != null && maxPoints > 0) {
    const pct = Math.round((pointsEarned / maxPoints) * 100);
    gradeStr = `You received ${pct}% (${pointsEarned}/${maxPoints})`;
  }

  const tokens = await getDeviceTokensForUsers([studentId]);

  const payload: APNsPayload = {
    aps: {
      alert: {
        title: "Grade Posted",
        body: `${gradeStr} on "${assignmentTitle}".`,
      },
      sound: "default",
      category: "GRADE_POSTED",
    },
    type: "grade",
    assignmentId: assignmentId,
    courseId: assignment?.course_id as string | undefined,
  };

  const results = await Promise.allSettled(
    tokens.map((t) => sendPushNotification(t.token, payload))
  );

  const sent = results.filter(
    (r) => r.status === "fulfilled" && r.value
  ).length;
  console.log(
    `[on_grade_entered] Sent ${sent}/${tokens.length} notifications for grade on "${assignmentTitle}"`
  );
}

/**
 * Triggered when a new message is sent.
 * Sends a push notification to all members of the conversation
 * except the sender.
 */
async function onMessageSent(
  record: Record<string, unknown>
): Promise<void> {
  const conversationId = record.conversation_id as string;
  const senderId = record.sender_id as string;
  const content = record.content as string;

  const supabase = getSupabaseClient();

  // Get sender name
  const { data: sender } = await supabase
    .from("profiles")
    .select("first_name, last_name")
    .eq("id", senderId)
    .single();

  const senderName = sender
    ? `${sender.first_name ?? ""} ${sender.last_name ?? ""}`.trim()
    : "Someone";

  // Get all conversation members except the sender
  const { data: members } = await supabase
    .from("conversation_members")
    .select("user_id")
    .eq("conversation_id", conversationId)
    .neq("user_id", senderId);

  if (!members || members.length === 0) return;

  const userIds = members.map((m: { user_id: string }) => m.user_id);
  const tokens = await getDeviceTokensForUsers(userIds);

  // Truncate message preview
  const preview =
    content.length > 100 ? content.substring(0, 97) + "..." : content;

  const payload: APNsPayload = {
    aps: {
      alert: {
        title: `New Message from ${senderName}`,
        body: preview,
      },
      sound: "default",
      category: "NEW_MESSAGE",
    },
    type: "message",
    conversationId: conversationId,
  };

  const results = await Promise.allSettled(
    tokens.map((t) => sendPushNotification(t.token, payload))
  );

  const sent = results.filter(
    (r) => r.status === "fulfilled" && r.value
  ).length;
  console.log(
    `[on_message_sent] Sent ${sent}/${tokens.length} notifications in conversation ${conversationId.substring(0, 8)}...`
  );
}

/**
 * Triggered when a new announcement is created.
 * Sends a push notification to all users in the school (tenant).
 */
async function onAnnouncementCreated(
  record: Record<string, unknown>
): Promise<void> {
  const title = record.title as string;
  const content = record.content as string;
  const schoolId = record.tenant_id as string | undefined;

  if (!schoolId) {
    console.warn("[on_announcement_created] No tenant_id found on record.");
    return;
  }

  const tokens = await getDeviceTokensForSchool(schoolId);

  const preview =
    content.length > 100 ? content.substring(0, 97) + "..." : content;

  const payload: APNsPayload = {
    aps: {
      alert: {
        title: `Announcement: ${title}`,
        body: preview,
      },
      sound: "default",
      "mutable-content": 1,
    },
    type: "announcement",
  };

  const results = await Promise.allSettled(
    tokens.map((t) => sendPushNotification(t.token, payload))
  );

  const sent = results.filter(
    (r) => r.status === "fulfilled" && r.value
  ).length;
  console.log(
    `[on_announcement_created] Sent ${sent}/${tokens.length} notifications for "${title}"`
  );
}

// ---------------------------------------------------------------------------
// Edge Function Entry Point
// ---------------------------------------------------------------------------

serve(async (req: Request) => {
  // Only accept POST requests (webhook payloads).
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body: WebhookPayload = await req.json();

    // Only process INSERT events.
    if (body.type !== "INSERT") {
      return new Response(
        JSON.stringify({ message: "Ignored non-INSERT event" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Route to the appropriate handler based on the source table.
    switch (body.table) {
      case "assignments":
        await onAssignmentCreated(body.record);
        break;

      case "grades":
        await onGradeEntered(body.record);
        break;

      case "messages":
        await onMessageSent(body.record);
        break;

      case "announcements":
        await onAnnouncementCreated(body.record);
        break;

      default:
        console.log(`[send-push] Unhandled table: ${body.table}`);
        return new Response(
          JSON.stringify({ message: `Unhandled table: ${body.table}` }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[send-push] Error processing webhook:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
