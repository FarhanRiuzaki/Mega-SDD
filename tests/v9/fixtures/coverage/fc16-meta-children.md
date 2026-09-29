# PRD: Clinic Booking

## 1. Introduction
### 1.1 Purpose
This document specifies the clinic booking web app, release 1.0.
### 1.2 Document Conventions
Priorities are marked P1–P3.
### 1.3 Intended Audience and Reading Suggestions
Developers, testers and the clinic's product owner.

## Problem Statement
Front-desk staff miss 30% of booking calls at peak hours.
### Pain Points
Patients wait on hold; staff re-key bookings into two systems.

## Personas
### Dewi — clinic admin
Runs the calendar for five doctors.
### Persona 2: Budi (Patient)
Books for his parents from his phone.

## Stakeholders
### Engineering
Andi leads the two-person team.

## Success Metrics
### North Star Metric
Share of bookings made online.

## Features
### Book a slot
A patient picks a doctor and a free slot and confirms with name and phone.
### Cancel a booking
A patient cancels from the confirmation link up to 2 hours before.

## Assumptions
### Technical Assumptions
The doctor-calendar service keeps its current API.

## Dependencies
### External APIs
The SMS gateway contract is renewed in Q3.

## Risks
### R1 — Payment gateway downtime
Mitigation: fall back to pay-at-clinic.

## Timeline & Milestones
### Phase 1 (Q1)
Beta for one clinic.

## Open Questions
### Business
- Do we charge a no-show fee?
### Technical
- Which SMS provider?

## Glossary
### Terms
Slot — a 15-minute calendar interval.

## Revision History
### v1.0 — 2026-01-10
First draft.

## Appendix
### A. Wireframes
Figma: https://figma.com/file/clinic-booking
### Competitive analysis
Two nearby clinics already offer online booking.
### User research
Interview notes from 12 patients are in the project folder.

# §Appendix

## A. Diagrams

- ERD: <link or embed>
- User flow diagrams: <link or embed>
