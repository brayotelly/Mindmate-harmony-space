#-
 MindMate Harmony Space

A gentle AI-powered companion that understands your emotions and supports your mental well-being.

MindMate Harmony Space is a simple but powerful AI-driven smart diary designed to help users express their feelings, understand their emotional patterns, and receive supportive guidance. Built with Jaseci, this project combines intelligent backend agents with a minimal, friendly frontend to create a safe emotional reflection space.

What This Project Does

You type what you’re feeling — for example:

> “I feel overwhelmed today.”



MindMate instantly:

1. Analyzes your mood using an Emotion Analyzer agent


2. Understands the tone (e.g., anxious, sad, happy, confused)


3. Generates a comforting, human-like response using the Companion agent


4. Logs your mood for future reflections on the dashboard



The goal is to create a calm, supportive experience where users can journal, reflect, and feel seen.


---

🧠 How It Works

The project has two main parts:

🔺 1. Backend (The Brain)

Located in the backend/ folder:

walkers.jac → AI agents: Mood Logger, Emotion Analyzer, Support Planner

byLLM_prompts.jac → Custom prompts used by the model

seed_data.jac → Sample data for testing


This is where all the intelligence lives.

🔻 2. Frontend (The Face)

Located in the frontend/ folder:

mood_logger.jc → Simple UI for journaling

dashboard.jc → Optional mood trends view


This is what the user interacts with.


---

🎯 Why This Project Matters

Mental well-being tools are often complicated or intimidating.
MindMate Harmony Space focuses on:

Simplicity

Empathy

Privacy

Emotional clarity


It’s not meant to diagnose anything — it’s simply a supportive space for your thoughts and feelings.


---

🛠️ Tech Stack

Jaseci (LLM Orchestration)

byLLM for emotion analysis + response generation

Python (for running the app
