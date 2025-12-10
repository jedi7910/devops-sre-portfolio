# SLIs, SLOs, and Error Budgets - SRE Fundamentals

Quick reference for service reliability engineering concepts - understanding reliability targets and risk management.

---

## Core Definitions

### SLI (Service Level Indicator)
**What:** The actual measurement/metric you track

**Think:** "What am I measuring?"

**Common SLIs:**
- **Availability:** % of successful requests (non-error responses)
- **Latency:** % of requests served under threshold (e.g., < 200ms)
- **Error rate:** % of failed requests
- **Throughput:** Requests per second

**Example formulas:**
```
Availability SLI = (Successful requests / Total requests) × 100
Latency SLI = (Requests < 200ms / Total requests) × 100
```

---

### SLO (Service Level Objective)
**What:** The target/goal for your SLI

**Think:** "What's our promise/commitment?"

**Examples:**
- Availability SLO: 99.9% of requests succeed
- Latency SLO: 95% of requests complete in < 200ms (p95)
- Error rate SLO: < 0.1% of requests fail

**Key point:** This is your internal commitment (may align with external SLAs)

---

### Error Budget
**What:** The amount of "failure" allowed before violating your SLO

**Think:** "How much can we break before we're in trouble?"

**Calculation:**
```
Error Budget = 100% - SLO

Example:
SLO = 99.9% availability
Error Budget = 0.1% downtime allowed
```

---

## The Most Important Number to Remember

**99.9% SLO = 43 minutes downtime per month**

This is the most commonly referenced SLO. Remember this one number and you can reason about others.

---

## Error Budget to Downtime Conversion

| SLO | Downtime/Month | Downtime/Week | Downtime/Day |
|-----|----------------|---------------|--------------|
| 99% | 7.2 hours | 1.68 hours | 14.4 min |
| 99.5% | 3.6 hours | 50.4 min | 7.2 min |
| **99.9%** | **43.2 min** | **10.1 min** | **1.44 min** |
| 99.95% | 21.6 min | 5 min | 43 sec |
| 99.99% | 4.32 min | 1 min | 8.6 sec |

---

## How They Work Together

### Real Example: Web Application

**SLI (What we measure):**
```
Availability = (Non-5xx responses / Total requests) × 100
```

**SLO (What we target):**
```
99.9% availability over 30 days
```

**Error Budget (What we're allowed):**
```
0.1% failed requests
= 43 minutes downtime per month
= ~1,000 failed requests per 1M total requests
```

---

## Error Budget Policy

How teams use error budgets to make decisions:

| Error Budget Remaining | Action |
|------------------------|--------|
| **> 50%** | Full speed - push features, take risks |
| **25-50%** | Caution - review risky changes carefully |
| **10-25%** | Slow down - only necessary changes |
| **< 10%** | FREEZE - reliability work only, no features |
| **0% (exhausted)** | Code freeze - incident response mode |

**Key insight:** This balances dev velocity (ship fast) vs ops reliability (don't break things)

---

## Interview Talking Points

### "Explain SLIs, SLOs, and error budgets"

**30-second answer:**

"SLIs are what you measure - the actual metrics like availability or latency. SLOs are your targets - for example, 99.9% uptime. The error budget is the gap between 100% and your SLO - it's how much you're allowed to fail.

The key insight is error budgets balance velocity and reliability. If you're within budget, you can move fast and take risks. If you've burned your budget, you slow down and focus on stability. It's a data-driven way to negotiate between shipping features and maintaining reliability.

For example, a 99.9% availability SLO gives you 43 minutes of allowed downtime per month. If an outage burns 30 minutes, you have 13 minutes left - time to be more cautious with deployments."

---

### "How would you implement SLOs for a new service?"

**Structured answer:**

1. **Choose SLIs:** Identify what matters to users (availability, latency, error rate)

2. **Set realistic SLOs:** Base on current performance + business needs
   - Don't start at 99.99% - that's expensive
   - Start at 99.9% or 99.5% if you're new
   - Balance cost vs user expectations

3. **Measure error budget:** Track consumption, alert at thresholds (50%, 75% used)

4. **Create policy:** Define actions at different budget levels

5. **Iterate:** Adjust based on reality
   - Too tight? Over-engineering
   - Too loose? Users don't notice the difference

**Key principle:** "The goal isn't perfection - it's finding the right balance between reliability and velocity"

---

### "What happens when you exhaust your error budget?"

**Answer:**

"When error budget is exhausted, the team shifts from feature development to reliability work:

1. **Deployment freeze:** Only critical bug fixes, no new features
2. **Root cause analysis:** Understand what burned the budget
3. **Reliability improvements:** Fix underlying issues, improve monitoring, add automation
4. **Gradual return:** As budget recovers, gradually resume feature work

This creates accountability - if we break things, we fix them before moving forward. It prevents the 'ship fast, break things, never fix them' cycle."

---

## Common SLO Examples

### Web Application
```
Availability: 99.9% of HTTP requests return non-5xx
Latency: 95% of requests < 500ms (p95)
Error Budget: 43 min downtime/month
```

### API Service
```
Availability: 99.95% of API calls succeed
Latency: 99% under 100ms, 99.9% under 1s
Error Budget: 21 min downtime/month
```

### Background Job Processor
```
Throughput: 95% of jobs complete within 5 minutes
Success Rate: 99.5% of jobs complete successfully
Error Budget: ~3,600 failed jobs per million
```

### Database
```
Availability: 99.99% query success rate
Latency: 99% of queries under 10ms
Error Budget: 4.3 min downtime/month
```

---

## Real-World Application (Your Experience)

### IBM Load Balancer Example

**SLIs measured:**
- Load balancer availability (uptime percentage)
- Failover speed (time to redirect traffic after failure)
- Request success rate (non-error responses)

**SLOs committed:**
- 99.95% availability (21.6 minutes downtime/month)
- Failover in < 5 seconds
- < 0.05% error rate

**Error Budget:**
- 0.05% downtime = ~22 minutes/month
- Could tolerate 4-5 brief outages per month
- BGP failover kept us within budget (sub-second recovery)

**When budget was threatened:**
- Paused risky maintenance windows
- Implemented better config validation
- Added automated testing before production changes
- Improved monitoring to catch issues earlier

---

## Key Formulas

### Calculate Error Budget from SLO
```
Error Budget (%) = 100% - SLO (%)

Example:
99.9% SLO → 0.1% error budget
```

### Convert to Time
```
Monthly downtime = (Error Budget % / 100) × 43,200 minutes

Example:
0.1% × 43,200 = 43.2 minutes/month
```

### Calculate SLI
```
Availability SLI = (Successful requests / Total requests) × 100

Example:
999,500 successful / 1,000,000 total = 99.95%
```

### Track Budget Consumption
```
Budget Used = (Actual downtime / Allowed downtime) × 100

Example:
30 min actual / 43.2 min allowed = 69.4% used
31.8% budget remaining
```

---

## Monitoring Error Budgets

### Prometheus Queries

**Availability SLI:**
```promql
# Success rate over last 30 days
sum(rate(http_requests_total{status!~"5.."}[30d])) 
/ 
sum(rate(http_requests_total[30d]))
```

**Error budget consumption:**
```promql
# How much budget is left?
1 - (
  sum(rate(http_requests_total{status!~"5.."}[30d]))
  /
  sum(rate(http_requests_total[30d]))
) / 0.001  # 0.001 = 99.9% SLO
```

**Alert when budget is low:**
```yaml
alert: ErrorBudgetLow
expr: error_budget_remaining < 0.25  # 25% remaining
for: 5m
annotations:
  summary: "Only {{ $value }}% error budget remaining"
```

---

## Common Mistakes to Avoid

❌ **Setting SLOs too high:** 99.99% sounds good but is expensive and often unnecessary
✅ **Start realistic:** Match user expectations and current performance

❌ **Too many SLOs:** Tracking 20 different metrics dilutes focus
✅ **Pick 2-3 critical ones:** What actually matters to users?

❌ **No error budget policy:** Having a budget but no action plan
✅ **Define clear actions:** What happens at 50%, 25%, 10%, 0% remaining?

❌ **Ignoring the budget:** Continuing risky deployments when budget is low
✅ **Respect the budget:** It's a negotiation tool, not a suggestion

❌ **Perfection mindset:** Aiming for 100% reliability
✅ **Balance mindset:** Find the right reliability/velocity tradeoff

---

## The Philosophy

**Key SRE principle:**
> "Hope is not a strategy, but neither is 100% reliability"

**Why this matters:**
- 100% reliability is impossible and infinitely expensive
- Users often can't tell 99.9% from 99.99%
- Error budgets let you spend reliability "budget" on innovation
- Data-driven decisions beat gut feelings

**The goal:**
Make reliability a feature with a cost, not an absolute requirement. Balance shipping fast with staying stable.

---

## Quick Reference Card

**Remember these three things:**

1. **SLI** = What you measure (availability, latency, errors)
2. **SLO** = Your target (99.9% uptime)
3. **Error Budget** = 100% - SLO (0.1% = 43 min/month)

**The one number:** 99.9% SLO = 43 minutes/month

**The one concept:** Error budgets balance speed and reliability

**That's it. You're ready for any SRE interview question about this.**

---

## Related Documentation

- [VM Operations Lab](../../vm-operations-lab-guide.md)
- [MySQL Operations](../mysql-operations/README.md)
- [Prometheus/Grafana](../observability/README.md)
- [GitLab CI/CD](../gitlab-ci-cd/README.md)

---

## Further Learning

- Google SRE Book - Chapter 4 (Service Level Objectives): https://sre.google/sre-book/service-level-objectives/
- Google SRE Workbook - Chapter 2 (Implementing SLOs): https://sre.google/workbook/implementing-slos/
- Atlassian SRE Handbook: https://www.atlassian.com/incident-management/kpis/sla-vs-slo-vs-sli