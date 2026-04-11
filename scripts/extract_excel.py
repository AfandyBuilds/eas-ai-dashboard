import pandas as pd
import json

xlsx = pd.ExcelFile('ReferencesAndGuidance/AI_Use_Case_Asset_Template (5).xlsx')
print('Sheets:', xlsx.sheet_names)

for sheet in xlsx.sheet_names:
    df = pd.read_excel(xlsx, sheet_name=sheet)
    print(f'\n=== Sheet: {sheet} ===')
    print(f'Shape: {df.shape}')
    print(f'Columns: {list(df.columns)}')
    print(df.head(5).to_string())
    print('---')
