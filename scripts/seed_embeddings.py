import os
import re
import sys
import requests
import psycopg2
from psycopg2.extras import execute_batch
from dotenv import load_dotenv

# Load environment variables from the root .env file
load_dotenv(dotenv_path="../.env")

# Database configuration
DB_HOST     = os.getenv("DB_HOST", "localhost")
DB_PORT     = os.getenv("DB_PORT", "5432")
DB_USER     = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123456")
DB_NAME     = os.getenv("DB_NAME", "ticket_sla")

# Ollama configuration — matches .env so vectors are always consistent
OLLAMA_URL   = os.getenv("EMBEDDING_SERVICE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")


def clean_text(text: str) -> str:
    if not text:
        return ""
    text = text.strip()
    text = re.sub(r'\s+', ' ', text)
    return text


def get_embedding(text: str) -> list[float]:
    """Call Ollama /api/embeddings endpoint — same model as Go backend uses."""
    resp = requests.post(
        f"{OLLAMA_URL}/api/embeddings",
        json={"model": OLLAMA_MODEL, "prompt": text},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["embedding"]


def check_ollama():
    """Verify Ollama is running and the model is available."""
    try:
        resp = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        models = [m["name"] for m in resp.json().get("models", [])]
        # Check prefix match (e.g. "nomic-embed-text:latest" matches "nomic-embed-text")
        if not any(m.startswith(OLLAMA_MODEL) for m in models):
            print(f"[ERROR] Model '{OLLAMA_MODEL}' not found in Ollama.")
            print(f"  Run: ollama pull {OLLAMA_MODEL}")
            print(f"  Available: {models}")
            sys.exit(1)
        print(f"✓ Ollama is running. Model '{OLLAMA_MODEL}' is available.")
    except Exception as e:
        print(f"[ERROR] Cannot connect to Ollama at {OLLAMA_URL}: {e}")
        print("  Make sure Ollama is running: ollama serve")
        sys.exit(1)


def main():
    print(f"Embedding model : {OLLAMA_MODEL}  (via Ollama at {OLLAMA_URL})")
    check_ollama()

    print(f"\nConnecting to database {DB_NAME} at {DB_HOST}:{DB_PORT}...")
    try:
        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT,
            user=DB_USER, password=DB_PASSWORD,
            dbname=DB_NAME,
        )
        cur = conn.cursor()
    except Exception as e:
        print(f"[ERROR] Failed to connect to DB: {e}")
        return

    # 1. Sub Departments — embed description with 'Description:' prefix
    print("\n--- Processing sub_departments ---")
    cur.execute("SELECT code, description FROM sub_departments")
    sub_deps = cur.fetchall()

    if sub_deps:
        print(f"Generating embeddings for {len(sub_deps)} sub_departments...")
        update_data = []
        for i, (code, description) in enumerate(sub_deps, 1):
            clean_desc = clean_text(description)
            semantic_text = f"Description: {clean_desc}"
            vec = get_embedding(semantic_text)
            update_data.append((str(vec), OLLAMA_MODEL, code))
            print(f"  [{i}/{len(sub_deps)}] {code} — {len(vec)} dims", end="\r")

        execute_batch(cur, """
            UPDATE sub_departments
            SET embedding = %s, embedding_model = %s
            WHERE code = %s
        """, update_data)
        conn.commit()
        print(f"\n✓ Updated {len(sub_deps)} sub_departments embeddings.")
    else:
        print("No sub_departments found.")

    # 2. Sample Tickets — embed "Title: ...\nDescription: ..."
    print("\n--- Processing sample_tickets ---")
    cur.execute("SELECT id, title, description FROM sample_tickets")
    tickets = cur.fetchall()

    if tickets:
        print(f"Generating embeddings for {len(tickets)} sample_tickets...")
        update_data = []
        for i, (t_id, title, description) in enumerate(tickets, 1):
            combined = f"Title: {clean_text(title)}\nDescription: {clean_text(description)}"
            vec = get_embedding(combined)
            update_data.append((str(vec), OLLAMA_MODEL, t_id))
            print(f"  [{i}/{len(tickets)}] id={t_id} — {len(vec)} dims", end="\r")

        execute_batch(cur, """
            UPDATE sample_tickets
            SET embedding = %s, embedding_model = %s
            WHERE id = %s
        """, update_data, page_size=100)
        conn.commit()
        print(f"\n✓ Updated {len(tickets)} sample_tickets embeddings.")
    else:
        print("No sample_tickets found.")

    cur.close()
    conn.close()
    print(f"\nDone! Vector DB seeded with {OLLAMA_MODEL} embeddings.")


if __name__ == "__main__":
    main()
