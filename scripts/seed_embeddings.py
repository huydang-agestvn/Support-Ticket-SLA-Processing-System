import os
import psycopg2
from psycopg2.extras import execute_batch
from sentence_transformers import SentenceTransformer
from dotenv import load_dotenv

# Load environment variables from the root .env file
load_dotenv(dotenv_path="../.env")

# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123456")
DB_NAME = os.getenv("DB_NAME", "ticket_sla")

MODEL_NAME = "all-MiniLM-L6-v2"

import re

def clean_text(text: str) -> str:
    if not text:
        return ""
    # Strip whitespace at ends
    text = text.strip()
    # Replace multiple spaces/newlines/tabs with a single space
    text = re.sub(r'\s+', ' ', text)
    return text

def main():
    print(f"Loading embedding model: {MODEL_NAME}...")
    # This will download the model to your local HuggingFace cache on first run
    model = SentenceTransformer(MODEL_NAME)
    
    print(f"Connecting to database {DB_NAME} at {DB_HOST}:{DB_PORT}...")
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            dbname=DB_NAME
        )
        cur = conn.cursor()
    except Exception as e:
        print(f"Failed to connect to DB: {e}")
        return

    # 1. Update Sub Departments
    print("\n--- Processing sub_departments ---")
    # Forcing update of all rows so the new cleaned vectors replace the old ones
    cur.execute("SELECT code, description FROM sub_departments")
    sub_deps = cur.fetchall()
    
    if sub_deps:
        print(f"Found {len(sub_deps)} sub_departments. Generating clean embeddings...")
        update_data = []
        for code, description in sub_deps:
            # Clean and generate vector
            clean_desc = clean_text(description)
            # Use 'Description:' prefix to match the format of tickets for better semantic similarity
            semantic_text = f"Description: {clean_desc}"
            vec = model.encode(semantic_text).tolist()
            update_data.append((str(vec), MODEL_NAME, code))
            
        update_query = """
            UPDATE sub_departments 
            SET embedding = %s, embedding_model = %s 
            WHERE code = %s
        """
        execute_batch(cur, update_query, update_data)
        conn.commit()
        print("Successfully updated sub_departments embeddings.")
    else:
        print("No sub_departments found.")

    # 2. Update Sample Tickets
    print("\n--- Processing sample_tickets ---")
    # Forcing update of all rows so the new cleaned vectors replace the old ones
    cur.execute("SELECT id, title, description FROM sample_tickets")
    tickets = cur.fetchall()
    
    if tickets:
        print(f"Found {len(tickets)} sample_tickets. Generating clean embeddings...")
        update_data = []
        for t_id, title, description in tickets:
            # Clean texts and generate vector
            clean_title = clean_text(title)
            clean_desc = clean_text(description)
            combined_text = f"Title: {clean_title}\nDescription: {clean_desc}"
            
            vec = model.encode(combined_text).tolist()
            update_data.append((str(vec), MODEL_NAME, t_id))
            
        update_query = """
            UPDATE sample_tickets 
            SET embedding = %s, embedding_model = %s 
            WHERE id = %s
        """
        # Batch size 100 to avoid memory spikes
        execute_batch(cur, update_query, update_data, page_size=100)
        conn.commit()
        print("Successfully updated sample_tickets embeddings.")
    else:
        print("No sample_tickets need updating.")

    cur.close()
    conn.close()
    print("\nDone! Vector Database is now fully seeded with 384-dimension embeddings.")

if __name__ == "__main__":
    main()
