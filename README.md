# SPH5104_Pneunomia_ADE
This repository contains all the SQL code (Standard-SQL) for data extraction on the MIMIC III database on Bigquery (Google Cloud Platform) for investigation on Impact of antibiotic de-escalation in individuals with culture-negative pneumonia in the intensive care unit (ICU). 

# Cohort Selection
* extract basic infromation for subjects aged 16 years and above with primary diagnosis of pneunomia, and exclude patients admitted to CSRU or TSICU

 1_First_query.sql

* select only patients with negative microbiology testing and at least on sample sent (This query additionally classifies patients based on microbiology findings into viral, bacterial, fungal or parasitic infection).

2_Second_query.sql
 
