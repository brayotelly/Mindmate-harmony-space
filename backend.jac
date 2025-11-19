# ===============================================
# walkers.jac
# MindMate backend agents (Jaseci / Jac)
# ===============================================
# DISCLAIMER (visible to judges/devs):
# This prototype is demo-only and NOT a medical or therapeutic tool.
# Keep sensitive personal data out of the demo dataset.
# ===============================================

# ---- Node definitions (simple, expressive) ----
# We create node "types" via simple archetypes: User, Entry, Emotion, Suggestion

new_node(User, "User")            # user node
new_node(Entry, "Entry")          # journal entry node
new_node(Emotion, "Emotion")      # emotion type node (e.g., ANXIOUS)
new_node(Suggestion, "Suggestion")# supportive reply / coping suggestion
new_node(Response, "Response")    # companion reply node

# ---- Helper function: timestamp ----
# Jac supports basic functions — create a lightweight timestamp helper
def now_str() -> str:
    return time.now().isoformat()  # if time.now().isoformat() unavailable, fallback to str(time.now())

# ---- Placeholder: byLLM call wrapper ----
# Replace byllm_call(...) with your actual integration.
# It returns a dictionary-like object, but for Jac simplicity we'll return a tuple (label, triggers, explanation)
# We provide a deterministic fallback to allow offline demo runs.

def byllm_call(prompt_name: str, text: str) -> (str, list, str):
    """
    prompt_name: key matching a prompt in byLLM_prompts.jac (e.g., "emotion_detection")
    text: user journal entry
    returns: (primary_emotion_label, triggers_list, explanation)
    """
    # === PLACEHOLDER: REPLACE THIS BLOCK with your real byLLM integration ===
    # Example pseudo-integration:
    # result = byllm.request(prompt=load_prompt(prompt_name), input_text=text)
    # return (result.label, result.triggers, result.explanation)
    #
    # For demo offline fallback, use simple keyword heuristics:
    lower = text.lower()
    if "sad" in lower or "depressed" in lower or "unhappy" in lower:
        return ("SAD", ["loss", "loneliness"], "keyword-match: sad")
    if "anx" in lower or "stress" in lower or "stressed" in lower:
        return ("ANXIOUS", ["exams", "work"], "keyword-match: anxious")
    if "happy" in lower or "great" in lower or "excited" in lower:
        return ("HAPPY", [], "keyword-match: happy")
    if "angry" in lower or "mad" in lower or "furious" in lower:
        return ("ANGRY", [], "keyword-match: angry")
    # default neutral
    return ("NEUTRAL", [], "fallback: neutral")

# ---- Utility: create or get emotion node ----
def get_or_create_emotion_node(label: str):
    # Check existing Emotion nodes for the same label
    nodes = get_nodes_by_type("Emotion")
    for n in nodes:
        if n.label == label:
            return n
    # else create
    return new(Emotion, {"label": label, "count": 0, "last_seen": now_str()})

# ---- Walker 1: Mood Logger ----
walker mood_logger(user_id: int = None, text: str):
    """
    Responsibilities:
      - Create a new Entry node (timestamp + content)
      - Link entry -> user
      - Spawn emotion_analyzer to label the entry (async spawn)
    Input:
      - user_id: optional existing user node id (if none, create a default demo user)
      - text: journal entry content
    Output:
      - returns entry node id
    """
    # 1. Resolve or create user
    if user_id:
        user = node(user_id)
    else:
        # create a demo user if missing
        user = new(User, {"name": "demo_user", "created": now_str()})
    
    # 2. Create entry node
    entry = new(Entry, {"text": text, "created": now_str()})
    
    # 3. Link entry -> user (simple edge)
    edge(user, "wrote", entry)
    
    # 4. Create a session attribute (optional)
    entry.set_attr("session_id", now_str())
    
    # 5. Spawn analyser (synchronous for demo clarity; could be spawned async)
    analyzer_res = spawn(emotion_analyzer, (entry.id,), join=True)
    # analyzer_res expected to return emotion label(s)
    
    emit("mood_logged", {"entry_id": entry.id, "analyzer": analyzer_res})
    return entry.id

# ---- Walker 2: Emotion Analyzer ----
walker emotion_analyzer(entry_id: int):
    """
    Responsibilities:
      - Read Entry text
      - Call byLLM to detect emotion + triggers
      - Create/Update Emotion node(s)
      - Attach emotion info to the Entry node (confidence, triggers)
    Input:
      - entry_id: id of the Entry node created by mood_logger
    Output:
      - returns a dictionary-like tuple (primary_label, triggers)
    """
    entry = node(entry_id)
    if not entry:
        return ("ERROR", [], "entry_not_found")
    
    text = entry.text
    
    # 1. Call byLLM (or fallback)
    (label, triggers, explanation) = byllm_call("emotion_detection", text)
    
    # 2. Create or reuse Emotion node
    emo_node = get_or_create_emotion_node(label)
    # increment count and update last seen
    emo_node.count = emo_node.count + 1
    emo_node.last_seen = now_str()
    
    # 3. Link entry -> emotion
    edge(entry, "expresses", emo_node)
    
    # 4. Save triggers as attributes or create Trigger nodes (simple attribute for now)
    entry.set_attr("emotion_label", label)
    entry.set_attr("emotion_triggers", triggers)
    entry.set_attr("analysis_explanation", explanation)
    
    # 5. Basic trend computation (lookback count in last N entries)
    # (This is a simple approximation: count emotion occurrences; advanced: traverse timestamps)
    entry.set_attr("emotion_count_total", emo_node.count)
    
    emit("emotion_analyzed", {"entry_id": entry_id, "label": label})
    return (label, triggers, explanation)

# ---- Walker 3: Support Companion ----
walker support_companion(entry_id: int):
    """
    Responsibilities:
      - Given an entry (and its emotion_label), generate a compassionate reply
      - Use byLLM with safety constraints
      - Create a Suggestion/Response node and link to Entry
    Input:
      - entry_id
    Output:
      - returns the text reply (string)
    """
    entry = node(entry_id)
    if not entry:
        return "Error: entry not found"
    
    label = entry.get_attr("emotion_label") or "NEUTRAL"
    triggers = entry.get_attr("emotion_triggers") or []
    text = entry.text
    
    # 1. Prepare the prompt content for byLLM
    prompt_input = """
    PROMPT: generate a short, compassionate, non-therapeutic response.
    USER_ENTRY: "{user_text}"
    LABEL: {label}
    TRIGGERS: {trigs}
    INSTRUCTIONS:
      - Keep under 50 words
      - Empathize, validate feeling, give a short coping idea (breathing, short walk, reach out)
      - Include a safety line: if in crisis, contact help (do not provide diagnosis)
      - No medical claims
    """.format(user_text=text, label=label, trigs=",".join(triggers))
    
    # 2. Call byLLM (or fallback)
    (gen_label, gen_trigs, explanation) = byllm_call("supportive_reply", prompt_input)
    # byllm_call returns fallback label info in our stub — for real integration, it should return a 'reply' text
    # For stub, craft a small rule-based reply:
    if label == "ANXIOUS":
        reply = "I hear you — it's okay to feel anxious. Try 4 deep breaths in and out. If it helps, take a short break and reach out to someone you trust. If you're in crisis, contact local help."
    elif label == "SAD":
        reply = "I'm sorry you're feeling sad. You're not alone — try writing one small thing that felt okay today. If you feel unsafe, please contact a professional or emergency services."
    elif label == "HAPPY":
        reply = "That's wonderful to hear! Celebrate the little wins — maybe jot down what made your day good so you can revisit it later."
    elif label == "ANGRY":
        reply = "It makes sense to feel angry. Consider a short walk or deep breaths to give yourself space. If things feel out of control, please reach out."
    else:
        reply = "Thanks for sharing. I'm here to listen — want to tell me more about what happened or how you feel?"
    
    # 3. Create Suggestion / Response node and link it
    resp = new(Response, {"text": reply, "created": now_str(), "based_on_label": label})
    edge(entry, "has_response", resp)
    
    # Optional: create a Suggestion node for structured coping plan
    suggestion = new(Suggestion, {"summary": reply, "emotion": label})
    edge(resp, "suggests", suggestion)
    
    emit("companion_replied", {"entry_id": entry_id, "response_id": resp.id})
    return reply

# ---- Demo routine (run this in jaseci console or spawn from controller) ----
# Example usage from a Python controller: spawn(mood_logger, (None, "I have exams and I am stressed")) 
# For direct Jac demo you can call:
def demo_flow():
    # create demo user
    demo_user = new(User, {"name": "DemoUser", "created": now_str()})
    # log three sample entries
    e1 = spawn(mood_logger, (demo_user.id, "I have exams next week and I am very stressed"))
    e2 = spawn(mood_logger, (demo_user.id, "I did well on my test today, I'm happy"))
    e3 = spawn(mood_logger, (demo_user.id, "I feel lonely and sad tonight"))
    # get companion replies for each
    r1 = spawn(support_companion, (e1,), join=True)
    r2 = spawn(support_companion, (e2,), join=True)
    r3 = spawn(support_companion, (e3,), join=True)
    # print (emit) short summary
    emit("demo_complete", {"r1": r1, "r2": r2, "r3": r3})
    return True

# End of walkers.jac
