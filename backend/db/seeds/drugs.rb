# PLACEHOLDER — seed data only, not a licensed drug database.
#
# Names below are public generic (INN) medication names, grouped by
# pharmacological class relevant to a heart-failure population and its
# common comorbidities (hypertension, diabetes, anticoagulation, lipid
# management, renal/thyroid, common short-term prescriptions). They exist to
# populate the enrollment screen's medication type-ahead (FR-N10/11) with
# free-text fallback for anything not listed — not as a source of dosing,
# interaction, or clinical guidance. See docs/OPEN_DECISIONS.md #4 (drug DB
# licensing) before using this table for anything beyond a type-ahead.
DRUGS_BY_CATEGORY = {
  "ACE inhibitor" => %w[
    Ramipril Enalapril Lisinopril Captopril Perindopril Benazepril
    Fosinopril Quinapril Trandolapril Cilazapril
  ],
  "ARB" => %w[
    Candesartan Losartan Valsartan Irbesartan Telmisartan Olmesartan
    Eprosartan Azilsartan
  ],
  "ARNI" => [ "Sacubitril/Valsartan" ],
  "Beta blocker" => %w[
    Bisoprolol Metoprolol Carvedilol Nebivolol Atenolol Propranolol
    Sotalol Esmolol Labetalol Acebutolol
  ],
  "Mineralocorticoid receptor antagonist" => %w[Spironolactone Eplerenone Finerenone],
  "SGLT2 inhibitor" => %w[Dapagliflozin Empagliflozin Canagliflozin Ertugliflozin],
  "Loop diuretic" => %w[Furosemide Torasemide Bumetanide],
  "Thiazide/thiazide-like diuretic" => %w[Hydrochlorothiazide Chlortalidone Indapamide Metolazone],
  "Potassium-sparing diuretic" => %w[Amiloride Triamterene],
  "Cardiac glycoside" => %w[Digoxin],
  "Anticoagulant" => %w[
    Warfarin Phenprocoumon Apixaban Rivaroxaban Dabigatran Edoxaban
    Heparin Enoxaparin Fondaparinux
  ],
  "Antiplatelet" => %w[Aspirin Clopidogrel Ticagrelor Prasugrel Dipyridamole],
  "Statin" => %w[Atorvastatin Simvastatin Rosuvastatin Pravastatin Fluvastatin Lovastatin Pitavastatin],
  "Other lipid-lowering" => %w[Ezetimibe Fenofibrate Bezafibrate Colestyramine Evolocumab Alirocumab],
  "Antiarrhythmic" => %w[Amiodarone Flecainide Propafenone Dronedarone Lidocaine Mexiletine Dofetilide],
  "Calcium channel blocker" => %w[Amlodipine Felodipine Nifedipine Verapamil Diltiazem Lercanidipine Isradipine],
  "Nitrate" => [ "Glyceryl trinitrate", "Isosorbide mononitrate", "Isosorbide dinitrate", "Molsidomine" ],
  "Other vasodilator" => %w[Hydralazine Minoxidil],
  "Other heart-failure agent" => %w[Ivabradine Ranolazine Milrinone],
  "Alpha blocker" => %w[Doxazosin Prazosin Terazosin],
  "Central-acting antihypertensive" => %w[Clonidine Moxonidine Methyldopa],
  "Renin inhibitor" => %w[Aliskiren],
  "Antidiabetic" => %w[
    Metformin Glimepiride Gliclazide Glibenclamide Sitagliptin Linagliptin
    Saxagliptin Vildagliptin Pioglitazone Acarbose Liraglutide Semaglutide
    Dulaglutide
  ],
  "Insulin" => [
    "Insulin glargine", "Insulin detemir", "Insulin aspart", "Insulin lispro",
    "Insulin degludec", "Insulin human"
  ],
  "Proton pump inhibitor" => %w[Omeprazole Pantoprazole Esomeprazole Lansoprazole Rabeprazole],
  "Thyroid" => %w[Levothyroxine Carbimazole Propylthiouracil],
  "Analgesic" => %w[Paracetamol Ibuprofen Diclofenac Tramadol Metamizole],
  "Gout" => %w[Allopurinol Febuxostat Colchicine],
  "Supplement" => [
    "Potassium chloride", "Magnesium oxide", "Ferrous sulfate", "Ferric carboxymaltose",
    "Cholecalciferol (vitamin D3)", "Folic acid", "Cyanocobalamin (vitamin B12)"
  ],
  "Antidepressant/anxiolytic" => %w[Sertraline Citalopram Escitalopram Mirtazapine Venlafaxine Lorazepam Diazepam],
  "Sleep aid" => %w[Zolpidem Zopiclone],
  "Antibiotic" => %w[Amoxicillin Ciprofloxacin Clarithromycin Doxycycline],
  "Bronchodilator/respiratory" => %w[Salbutamol Ipratropium Tiotropium Formoterol Salmeterol Budesonide],
  "Corticosteroid" => %w[Prednisolone Dexamethasone Hydrocortisone],
  "Laxative" => %w[Macrogol Bisacodyl Lactulose],
  "Antiemetic" => %w[Metoclopramide Domperidone Ondansetron],
  "Fixed-dose combination antihypertensive" => [
    "Ramipril/Hydrochlorothiazide", "Candesartan/Hydrochlorothiazide",
    "Amlodipine/Valsartan", "Bisoprolol/Hydrochlorothiazide",
    "Losartan/Hydrochlorothiazide", "Perindopril/Indapamide",
    "Olmesartan/Amlodipine", "Telmisartan/Amlodipine"
  ],
  "Other cardiac" => %w[Adenosine Digitoxin],
  "Other diuretic" => %w[Xipamide],
  "H2 blocker" => %w[Ranitidine Famotidine],
  "Other antidiabetic" => %w[Repaglinide Nateglinide],
  "Other thyroid" => %w[Liothyronine],
  "Cognitive/dementia" => %w[Donepezil Memantine Rivastigmine],
  "Antipsychotic (delirium/agitation)" => %w[Quetiapine Haloperidol Risperidone],
  "Antivertigo" => %w[Betahistine],
  "Antihistamine" => %w[Cetirizine Loratadine],
  "Other analgesic" => %w[Naproxen Etoricoxib],
  "Mineral supplement" => [ "Calcium carbonate", "Magnesium citrate" ]
}.freeze

DRUGS_BY_CATEGORY.each do |category, names|
  names.each do |name|
    Drug.find_or_create_by!(name: name) { |d| d.category = category }
  end
end

Rails.logger.info "Seeded #{Drug.count} drugs (PLACEHOLDER list, #{DRUGS_BY_CATEGORY.keys.size} categories)"
