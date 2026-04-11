import pandas as pd
import json

xlsx = pd.ExcelFile('ReferencesAndGuidance/AI_Use_Case_Asset_Template (5).xlsx')

# Read the Use Case Template sheet with header row 0
df = pd.read_excel(xlsx, sheet_name='Use Case Template', header=0)

with open('scripts/excel_raw.txt', 'w', encoding='utf-8') as f:
    f.write(f'Shape: {df.shape}\n')
    f.write(f'Columns: {list(df.columns)}\n\n')
    
    # Show unique departments
    dept_col = 'Department'
    f.write(f'Unique Departments: {df[dept_col].dropna().unique().tolist()}\n')
    f.write(f'Dept value counts:\n{df[dept_col].value_counts().to_string()}\n\n')
    
    # Unique Validation Feedback values
    f.write(f'Unique Validation Feedback: {df["Validation Feedback"].dropna().unique().tolist()}\n\n')

# Filter for EAS department
eas_df = df[df['Department'].astype(str).str.upper().str.strip() == 'EAS']

with open('scripts/excel_raw.txt', 'a', encoding='utf-8') as f:
    f.write(f'\nEAS rows: {len(eas_df)}\n')

# Also filter for Accepted Idea only (these are AI Innovation approved)
eas_accepted = eas_df[eas_df['Validation Feedback'].astype(str).str.contains('Accepted', case=False, na=False)]

with open('scripts/excel_raw.txt', 'a', encoding='utf-8') as f:
    f.write(f'EAS Accepted rows: {len(eas_accepted)}\n\n')

# Write all EAS rows as clean JSON
eas_records = []
for idx, row in eas_df.iterrows():
    record = {}
    for col in df.columns:
        val = row[col]
        if pd.notna(val):
            record[str(col)] = str(val).strip()
    eas_records.append(record)

with open('scripts/eas_use_cases.json', 'w', encoding='utf-8') as f:
    json.dump(eas_records, f, indent=2, ensure_ascii=False, default=str)

# Write accepted EAS rows as clean JSON
eas_accepted_records = []
for idx, row in eas_accepted.iterrows():
    record = {}
    for col in df.columns:
        val = row[col]
        if pd.notna(val):
            record[str(col)] = str(val).strip()
    eas_accepted_records.append(record)

with open('scripts/eas_accepted_use_cases.json', 'w', encoding='utf-8') as f:
    json.dump(eas_accepted_records, f, indent=2, ensure_ascii=False, default=str)

with open('scripts/excel_raw.txt', 'a', encoding='utf-8') as f:
    f.write(f'Wrote {len(eas_records)} total EAS records to eas_use_cases.json\n')
    f.write(f'Wrote {len(eas_accepted_records)} accepted EAS records to eas_accepted_use_cases.json\n')

print('Done!')
