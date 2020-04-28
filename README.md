# SPH5104_Pneunomia_ADE
This repository contains all the SQL code (Standard-SQL) for data extraction on the MIMIC III database on Bigquery (Google Cloud Platform) for investigation on Impact of antibiotic de-escalation in individuals with culture-negative pneumonia in the intensive care unit (ICU). 

# Cohort Selection
* extract basic infromation for subjects aged 16 years and above with primary diagnosis of pneunomia, and exclude patients admitted to CSRU or TSICU.

       1_First_query.sql

* select only patients with negative microbiology testing and at least on sample sent (This query additionally classifies patients based on microbiology findings into viral, bacterial, fungal and parasitic infection).

      2_Second_query.sql
 
* Extract patients antibiotic prescriptions and further classifiy all antibiotics into broad and narrow-spectrum abx.
       
       3_ABX_info.sql
       
* Extract all patients started on broad-spectrum abx before first blood culture test was drawn

       4_StartedOnBroad.sql


# Extract Information on the day were the blood culture was drawn 

* Laboratory tets and vital measurements

       LabOnCultureDay.sql
       VitalsOnCultureDay.sql

* Ventilation Information
       
       2.0_Ventilated_BoodCultureDay.sql

# Comorbidities 
* Comorbidities are extracted based on Enhanced ICD-9-CM
       
       Comorbidities.sql

# Translated code from MIMIC Code Repository (https://github.com/MIT-LCP/mimic-code) from PostgreSQL into StandardSQL 
* FirstDay 

        Firstday_BloodGas.sql 
        Firstday_BloodGasAterial.sql
        Firstday_GCS.sql
        Firstday_UrineOutput.sql
        
* Elixhauser Comorbidities

        2.0_ElixhauserComorbidities_ICD9.sql
        2.1_ElixhauserScore.sql
        
* Ventilation Information 

       1.0_Ventsettings.sql
       1.1_VentilationDuration.sql
        

