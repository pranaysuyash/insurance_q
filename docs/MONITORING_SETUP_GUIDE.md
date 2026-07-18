# CoverWise — Monitoring Setup Guide

**Purpose:** Step-by-step guide to set up uptime monitoring for the CoverWise backend `/health` endpoint.  
**Reference:** `docs/UX_ISSUES_AUTH_AUDIT.md` §12D  
**Recommended:** Betterstack (free tier) — 30-second checks, integrated incident management

---

## Prerequisites

1. **Deployed backend URL** — You need the HTTPS URL where the backend is running (e.g., `https://api.coverwise.app/health`)
2. **Email address** — For alert notifications
3. **Optional:** Slack workspace, phone number for SMS alerts

---

## Option A: Betterstack (Recommended)

Betterstack offers 30-second check frequency (vs UptimeRobot's 5 minutes) and integrated incident management — better for a production revenue-generating service.

### Step 1: Create Account

1. Go to [betterstack.com](https://betterstack.com)
2. Click **Start Free** → Sign up with email or Google
3. Verify your email

### Step 2: Add Uptime Monitor

1. Dashboard → **Uptime** → **Monitors** → **Add Monitor**
2. Configure:
   - **Monitor type:** HTTP(S)
   - **URL:** `https://YOUR_API_URL/health`
   - **Monitor name:** `CoverWise Backend Health`
   - **Check interval:** 30 seconds (free tier default)
   - **Regions:** Choose 2-3 regions (e.g., US East, Europe, Asia)
3. Click **Create Monitor**

### Step 3: Configure Alerts

1. Dashboard → **Uptime** → **Alert Policies** → **Add Alert Policy**
2. Add email notification:
   - **Channel:** Email
   - **Recipients:** Your email address
   - **Notify when:** Down for 1 minute (avoids false positives from brief blips)
3. Optional: Add Slack notification
   - **Channel:** Slack
   - **Webhook URL:** From your Slack workspace settings
   - **Channel:** `#alerts` or `#engineering`

### Step 4: Set Up Status Page (Optional)

1. Dashboard → **Status Pages** → **Add Status Page**
2. Name: `CoverWise Status`
3. Add the `CoverWise Backend Health` monitor
4. Publish → You get a public URL like `status.coverwise.app`

### Step 5: Verify

1. Visit the monitor page — should show **Up** with response time
2. Check your email for the confirmation/alert setup email
3. Optionally: temporarily change the URL to an invalid one to test alerting

---

## Option B: UptimeRobot

UptimeRobot offers 50 free monitors but with 5-minute check frequency — sufficient for a solo launch where sub-minute detection isn't critical.

### Step 1: Create Account

1. Go to [uptimerobot.com](https://uptimerobot.com)
2. Click **Register for FREE** → Sign up with email
3. Verify your email

### Step 2: Add Monitor

1. Dashboard → **Add New Monitor**
2. Configure:
   - **Monitor type:** HTTP(s)
   - **Friendly Name:** `CoverWise Backend Health`
   - **URL:** `https://YOUR_API_URL/health`
   - **Monitoring Interval:** 5 minutes (free tier)
3. Click **Create Monitor**

### Step 3: Configure Alerts

1. Dashboard → **My Settings** → **Alert Contacts** → **Add Alert Contact**
2. Choose **Email** → Enter your email → Save
3. Edit the monitor → **Alert Contacts** → Select your email contact
4. Optional: Add Slack webhook for team notifications

### Step 4: Verify

1. Monitor page should show **Up** status
2. Check email for confirmation

---

## What to Monitor

| Monitor | URL | Check Interval | Alert When |
|---|---|---|---|
| **Backend Health** | `https://YOUR_API_URL/health` | 30s (Betterstack) / 5min (UptimeRobot) | Down for 1 min |
| **Supabase Status** | N/A (check status.supabase.com) | Manual | Any incident |
| **Backend /healthz** | `https://YOUR_API_URL/healthz` | Same as above | Down for 1 min (optional) |

---

## Alert Thresholds (from §12C)

| Condition | Severity | Action |
|---|---|---|
| Health endpoint down for > 5 min | 🔴 P0 | Check backend logs, Supabase status, restart if needed |
| Response time > 5 seconds consistently | 🟡 P1 | Check database connections, external API latency |
| Health endpoint returns non-200 | 🟡 P1 | Check backend logs for specific error |

---

## Cost

| Service | Free Tier | Paid Tier (if needed) |
|---|---|---|
| **Betterstack** | 10 monitors, 30s checks, 1 status page | $24/mo for 50 monitors, 10s checks |
| **UptimeRobot** | 50 monitors, 5min checks, 1 status page | $7/mo for 50 monitors, 1min checks |

**Recommendation:** Start with Betterstack free tier. If you need more than 10 monitors, switch to UptimeRobot free tier.

---

*Last updated: 2026-07-18*
