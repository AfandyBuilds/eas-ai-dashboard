import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { OpenAI } from "https://esm.sh/openai@4.28.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY"),
});

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

/**
 * Fetch AI Innovation approved use cases from the database for validation context.
 * These serve as reference patterns for what constitutes a valid AI use case.
 */
async function fetchApprovedUseCasesSummary(): Promise<string> {
  try {
    if (!supabaseUrl || !supabaseServiceKey) return "";
    const sb = createClient(supabaseUrl, supabaseServiceKey);
    const { data, error } = await sb
      .from("use_cases")
      .select("asset_id, name, category, subcategory, sdlc_phase, ai_tools, practice")
      .eq("is_approved_reference", true)
      .eq("is_active", true)
      .limit(50);
    if (error || !data || data.length === 0) return "";
    const summary = data.map(
      (uc) =>
        `- ${uc.name} (${uc.category || ""}${uc.subcategory ? "/" + uc.subcategory : ""}) [${uc.ai_tools || ""}] — ${uc.practice}`
    );
    return summary.join("\n");
  } catch {
    return "";
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { submissionType, savedHours, whyText, whatText, aiTool, category } = await req.json();

    if (!submissionType || !["task", "accomplishment"].includes(submissionType)) {
      return new Response(
        JSON.stringify({ error: 'submissionType must be "task" or "accomplishment"' }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (typeof savedHours !== "number" || savedHours < 0) {
      return new Response(
        JSON.stringify({ error: "savedHours must be a non-negative number" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch approved use cases as validation reference context
    const approvedUseCasesSummary = await fetchApprovedUseCasesSummary();
    const approvedContext = approvedUseCasesSummary
      ? `\n\nREFERENCE — AI Innovation Approved Use Cases (use as benchmark for relevance and quality):\n${approvedUseCasesSummary}\n`
      : "";

    const validationRules = `Check the following AI task/accomplishment submission for quality and validity.
${approvedContext}
Submission Details:
- Saved Hours: ${savedHours}
- Why (Context): "${whyText || ""}"
- What (Accomplishment): "${whatText || ""}"
- AI Tool Used: "${aiTool || ""}"
- Category: "${category || ""}"

Validate against these rules:
1. **Mentions AI tool**: Check if "${aiTool || ""}" is a real AI tool (ChatGPT, Copilot, Claude, Gemini, etc.)
2. **Meaningful explanation (50+ words total)**: Check combined length of why+what texts
3. **Mentions quantifiable metrics**: Check if "why" or "what" mentions numbers, percentages, time, or specific outcomes
4. **Quality assessment**: Overall coherence and professional tone
5. **Saved hours**: Any amount saved counts (provided: ${savedHours}h)
6. **Alignment with approved use cases**: If approved use cases are provided above, check whether the submission aligns with known AI use case patterns. Bonus points if it matches or extends an approved pattern. Not a hard failure if it doesn't match — novel use cases are welcome.

Respond in JSON format:
{
  "isValid": true|false,
  "passedRules": ["rule 1", "rule 2"],
  "failedRules": ["rule 3"],
  "overallScore": 0-100,
  "reason": "Brief explanation",
  "suggestions": ["suggestion 1", "suggestion 2"],
  "matchedApprovedUseCase": "name of matching approved use case or null"
}`;

    const validation = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [{ role: "user", content: validationRules }],
      temperature: 0.5,
      max_tokens: 400,
    });

    const content = validation.choices[0].message.content;
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    const result = jsonMatch
      ? JSON.parse(jsonMatch[0])
      : {
          isValid: true,
          overallScore: 70,
          reason: "Could not parse AI response",
        };

    return new Response(
      JSON.stringify({
        submissionType,
        validation: result,
        timestamp: new Date().toISOString(),
      }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err) {
    console.error("AI validation error:", err);
    return new Response(
      JSON.stringify({
        error: `Validation failed: ${err.message || "Internal error"}`,
        fallback: {
          isValid: false,
          overallScore: 0,
          reason: "AI service temporarily unavailable",
        },
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
