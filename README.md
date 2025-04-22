# MIMICIV 3.1 Derived
Code for creating derived tables for MIMICIV 3.1 on BigQuery

1. Create a project in your BigQuery where you'll store your derived tables.  
    - In the provided SQL scripts the default project name is "mymimiciv".  You need to eplace this with your own project name. 
    - I have provided a Python file ```replace_project_name.py``` to automate this.  
    - First edit the Python file line #32 to replace this default name with your own project name and then run the file.

2. Order in which to run the SQL queries:
    - The file ```derived_sql_exec_order.txt``` lists the order in which I ran the scripts to ensure that the derived queries needed for other derived queries run first.