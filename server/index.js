/**
 * Stub parse service — extend with Hugging Face Inference (server-side token only).
 * POST /parse/batch
 * Body: { items: [{ id, snippet, subject, from, date_header }] }
 */
const express = require("express");

const app = express();
app.use(express.json({ limit: "2mb" }));

// India-first amounts; USD as fallback
const amountRe =
  /(?:Rs\.?|INR|₹|Rupees?)\s*([\d,]+(?:\.\d{1,2})?)|(?:debited|credited|paid|spent|txn)\s*[:\s]+(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)|\$\s*([\d,]+(?:\.\d{1,2})?)/i;

app.post("/parse/batch", (req, res) => {
  const items = req.body?.items;
  if (!Array.isArray(items)) {
    return res.status(400).json({ error: "items array required" });
  }
  const results = [];
  for (const it of items) {
    const text = `${it.subject || ""}\n${it.snippet || ""}`;
    const m = text.match(amountRe);
    const raw = m ? m[1] || m[2] || m[3] : null;
    const amount = raw ? parseFloat(raw.replace(/,/g, "")) : null;
    if (amount == null || Number.isNaN(amount)) continue;
    const currency = /INR|Rs\.?|₹|Rupee/i.test(text)
      ? "INR"
      : /\$|USD/i.test(text)
        ? "USD"
        : "INR";
    const type = /credited|received|जमा/i.test(text) ? "credit" : "debit";
    results.push({
      id: it.id,
      transaction_id: `gmail_${it.id}`,
      date_time: new Date().toISOString(),
      merchant: (it.subject || "").slice(0, 80) || null,
      amount,
      currency,
      type,
      payment_mode: /UPI|IMPS|NEFT|@ybl|@oksbi|@okhdfcbank|@okicici|@paytm/i.test(
        text,
      )
        ? /UPI|@/.test(text)
          ? "upi"
          : "bank_transfer"
        : "other",
      inferred_category: null,
      confidence_score: 0.55,
      raw_text: (it.snippet || "").slice(0, 4000),
    });
  }
  res.json({ results });
});

const port = process.env.PORT || 8787;
app.listen(port, () => {
  console.log(`fin-alert parse stub on http://localhost:${port}`);
});
