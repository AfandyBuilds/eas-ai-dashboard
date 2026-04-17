import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ---- Config ----

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

interface NewsItem {
  title: string;
  summary: string | null;
  url: string;
  source: string;
  topic: string;
  image_url: string | null;
  published_at: string;
  fetched_at: string;
}

// ---- RSS Feed Sources ----

const RSS_FEEDS: { source: string; url: string }[] = [
  { source: "anthropic",   url: "https://www.anthropic.com/rss.xml" },
  { source: "openai",      url: "https://openai.com/blog/rss.xml" },
  { source: "google",      url: "https://blog.google/technology/ai/rss/" },
  { source: "github",      url: "https://github.blog/feed/" },
  { source: "microsoft",   url: "https://blogs.microsoft.com/ai/feed/" },
  { source: "huggingface", url: "https://huggingface.co/blog/feed.xml" },
  { source: "verge",       url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml" },
  { source: "techcrunch",  url: "https://techcrunch.com/category/artificial-intelligence/feed/" },
];

// ---- Topic Classification ----

const TOPIC_RULES: { topic: string; keywords: RegExp }[] = [
  { topic: "new_model",   keywords: /\b(model|claude|gpt|gemini|llama|release|launch|o[1-9]|sonnet|opus|haiku)\b/i },
  { topic: "new_skill",   keywords: /\b(skill|agent|plugin|extension|marketplace|skills\.sh)\b/i },
  { topic: "api_update",  keywords: /\b(api|sdk|endpoint|developer|function.?calling|tool.?use)\b/i },
  { topic: "research",    keywords: /\b(paper|research|benchmark|safety|alignment|eval)\b/i },
  { topic: "enterprise",  keywords: /\b(enterprise|copilot|microsoft.?365|workspace|business|adoption)\b/i },
];

function classifyTopic(title: string, summary: string): string {
  const text = `${title} ${summary}`.toLowerCase();
  for (const rule of TOPIC_RULES) {
    if (rule.keywords.test(text)) return rule.topic;
  }
  return "industry";
}

// ---- XML Parsing Helpers ----

function extractTag(xml: string, tag: string): string {
  const cdataRe = new RegExp(`<${tag}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></${tag}>`, "i");
  const cdataMatch = xml.match(cdataRe);
  if (cdataMatch) return cdataMatch[1].trim();

  const plainRe = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, "i");
  const plainMatch = xml.match(plainRe);
  return plainMatch ? plainMatch[1].replace(/<[^>]+>/g, "").trim() : "";
}

function extractAttr(xml: string, tag: string, attr: string): string {
  const re = new RegExp(`<${tag}[^>]*${attr}="([^"]*)"`, "i");
  const m = xml.match(re);
  return m ? m[1] : "";
}

function parseDate(dateStr: string): string | null {
  if (!dateStr) return null;
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return null;
    return d.toISOString();
  } catch {
    return null;
  }
}

function truncate(str: string, maxLen: number): string {
  if (!str) return "";
  if (str.length <= maxLen) return str;
  return str.slice(0, maxLen - 1) + "\u2026";
}

// ---- Feed Fetching & Parsing ----

async function fetchFeed(source: string, feedUrl: string): Promise<NewsItem[]> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);

  try {
    const res = await fetch(feedUrl, {
      signal: controller.signal,
      headers: { "User-Agent": "EAS-AI-News-Aggregator/1.0" },
    });
    clearTimeout(timeout);

    if (!res.ok) {
      console.error(`[${source}] HTTP ${res.status}`);
      return [];
    }

    const xml = await res.text();
    return parseRSS(xml, source);
  } catch (err) {
    clearTimeout(timeout);
    console.error(`[${source}] Fetch failed: ${(err as Error).message}`);
    return [];
  }
}

function parseRSS(xml: string, source: string): NewsItem[] {
  const items: NewsItem[] = [];
  const now = new Date().toISOString();

  const isAtom = xml.includes("<feed") && xml.includes("<entry");
  const splitter = isAtom ? "<entry" : "<item";
  const parts = xml.split(splitter).slice(1);

  for (const part of parts) {
    const title = extractTag(part, "title");
    if (!title) continue;

    let url = "";
    if (isAtom) {
      url = extractAttr(part, 'link[^>]*rel="alternate"', "href") ||
            extractAttr(part, "link", "href");
    } else {
      url = extractTag(part, "link");
    }
    if (!url) continue;

    const summary = truncate(
      extractTag(part, "description") ||
        extractTag(part, "summary") ||
        extractTag(part, "content"),
      300
    );

    const pubDateStr = extractTag(part, "pubDate") ||
                       extractTag(part, "published") ||
                       extractTag(part, "updated");
    const published_at = parseDate(pubDateStr);
    if (!published_at) continue;

    const image_url =
      extractAttr(part, "media:content", "url") ||
      extractAttr(part, "media:thumbnail", "url") ||
      extractAttr(part, "enclosure", "url") ||
      null;

    const topic = classifyTopic(title, summary);

    items.push({
      title: truncate(title, 200),
      summary: summary || null,
      url,
      source,
      topic,
      image_url,
      published_at,
      fetched_at: now,
    });
  }

  return items;
}

// ---- skills.sh Scraping ----

async function fetchSkillsSh(): Promise<NewsItem[]> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    const res = await fetch("https://skills.sh/", {
      signal: controller.signal,
      headers: { "User-Agent": "EAS-AI-News-Aggregator/1.0" },
    });
    clearTimeout(timeout);

    if (!res.ok) {
      console.warn(`[skills_sh] HTTP ${res.status}`);
      return [];
    }

    const html = await res.text();
    const items: NewsItem[] = [];
    const now = new Date().toISOString();

    const skillPattern = /href="(\/[^"]+\/[^"]+\/[^"]+)"\s*[^>]*>([^<]+)/gi;
    let match;
    const seen = new Set<string>();

    while ((match = skillPattern.exec(html)) !== null) {
      const path = match[1];
      const name = match[2].trim();
      if (seen.has(path) || !name || name.length < 3) continue;
      seen.add(path);

      items.push({
        title: `New Skill: ${name}`,
        summary: `Agent skill available on skills.sh \u2014 install with npx skills add ${path.slice(1)}`,
        url: `https://skills.sh${path}`,
        source: "skills_sh",
        topic: "new_skill",
        image_url: null,
        published_at: now,
        fetched_at: now,
      });

      if (items.length >= 10) break;
    }

    return items;
  } catch (err) {
    console.warn(`[skills_sh] Scrape failed: ${(err as Error).message}`);
    return [];
  }
}

// ---- Main Handler ----

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (authHeader) {
    const supabaseAuth = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error } = await supabaseAuth.auth.getUser(token);
    if (error || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const { data: profile } = await supabaseAuth
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();
    if (!profile || profile.role !== "admin") {
      return new Response(JSON.stringify({ error: "Admin role required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const stats = { inserted: 0, skipped: 0, errors: [] as string[] };

  const feedPromises = RSS_FEEDS.map((f) => fetchFeed(f.source, f.url));
  feedPromises.push(fetchSkillsSh());

  const results = await Promise.allSettled(feedPromises);
  const allItems: NewsItem[] = [];

  for (const result of results) {
    if (result.status === "fulfilled") {
      allItems.push(...result.value);
    } else {
      stats.errors.push(result.reason?.message || "Unknown feed error");
    }
  }

  for (const item of allItems) {
    const { error } = await sb.from("ai_news").upsert(
      {
        title: item.title,
        summary: item.summary,
        url: item.url,
        source: item.source,
        topic: item.topic,
        image_url: item.image_url,
        published_at: item.published_at,
        fetched_at: item.fetched_at,
      },
      { onConflict: "url" }
    );
    if (error) {
      stats.errors.push(`[${item.source}] ${error.message}`);
      stats.skipped++;
    } else {
      stats.inserted++;
    }
  }

  const { error: cleanupErr } = await sb
    .from("ai_news")
    .delete()
    .lt("published_at", new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());

  if (cleanupErr) {
    stats.errors.push(`Cleanup: ${cleanupErr.message}`);
  }

  console.log(`AI News aggregation complete: ${stats.inserted} inserted, ${stats.skipped} skipped, ${stats.errors.length} errors`);

  return new Response(JSON.stringify(stats), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
