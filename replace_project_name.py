import os

def find_and_replace_in_sql(root_folder, old_word, new_word):
    """
    Recursively searches for .sql files within a root folder and replaces
    all occurrences of an old word with a new word in each file.

    Args:
        root_folder (str): The path to the root folder containing the .sql files.
        old_word (str): The word to be replaced.
        new_word (str): The word to replace with.
    """
    for dirpath, dirnames, filenames in os.walk(root_folder):
        for filename in filenames:
            if filename.endswith(".sql"):
                filepath = os.path.join(dirpath, filename)
                try:
                    with open(filepath, 'r') as file:
                        content = file.read()

                    new_content = content.replace(old_word, new_word)

                    with open(filepath, 'w') as file:
                        file.write(new_content)
                    print(f"Replaced '{old_word}' with '{new_word}' in: {filepath}")
                except Exception as e:
                    print(f"Error processing file {filepath}: {e}")

if __name__ == "__main__":
    folder_path = "concepts"
    old_string = "mymimiciv"
    new_string = {your_project_name} # replace this with your BigQuery project name
    find_and_replace_in_sql(folder_path, old_string, new_string)
    print("Search and replace operation completed.")