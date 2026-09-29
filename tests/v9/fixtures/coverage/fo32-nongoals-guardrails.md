# PRD: AI Financial Assistant

## 1. Problem Statement
Customers ask the call center the same 20 questions about their accounts.

## 2. Answer Account Questions
The assistant answers balance, spending and bill questions from the customer's own data.

## 3. Non-goals & Guardrails
- Not a financial advisor: the assistant MUST NOT recommend specific stocks, funds or loans.
- The assistant MUST NOT reveal data of any account the signed-in customer does not own.
- The assistant MUST NOT move money; payment requests are handed to the Transfer screen.

## 4. Feedback
Every answer carries thumbs-up / thumbs-down; the rating is stored with the conversation id.
