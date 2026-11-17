# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "54f8cae4-325c-4c78-adf7-81d61756842b",
# META       "default_lakehouse_name": "lh_Bronze_MG",
# META       "default_lakehouse_workspace_id": "15dede2e-b9d9-4ce7-a199-3337b30e53e2",
# META       "known_lakehouses": [
# META         {
# META           "id": "54f8cae4-325c-4c78-adf7-81d61756842b"
# META         }
# META       ]
# META     }
# META   }
# META }

# PARAMETERS CELL ********************

run_id  = "manual-run"
wm_from = "1900-01-01T00:00:00"   # Lookup_Old_WM  → dbo.Silver_Watermark
wm_to   = "1900-01-01T00:00:00"   # Lookup_New_WM  → dbo.Bronze_Watermark

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **Import-ები და კონსტანტები**

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql.window import Window
from delta.tables import DeltaTable
import datetime
import json
import time
import sempy.fabric as fabric
spark.conf.set("spark.sql.session.timeZone", "UTC")
BRONZE_TABLE     = "lh_Bronze_MG.dbo.Raw_Bronze_Data"
SILVER_TABLE     = "lh_Silver_MG.dbo.Silver_Sales"
REJECTED_TABLE   = "lh_Silver_MG.dbo.Silver_Rejected"
CHANGE_LOG_TABLE = "lh_Silver_MG.dbo.Silver_Change_Log"


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **ფანჯრის განსაზღვრა პარამეტრებიდან**

# CELL ********************

def parse_ts(s):
    return datetime.datetime.fromisoformat(s.strip().replace(" ", "T"))
last_wm  = parse_ts(wm_from)
upper_wm = parse_ts(wm_to)

print("Silver Old Watermark (wm_from):", last_wm)
print("Bronze Watermark     (wm_to):  ", upper_wm)

if upper_wm <= last_wm:
    notebookutils.notebook.exit(json.dumps({
        "Status": "NoData", "RowsRead": 0, "RowsValid": 0,
        "RowsRejected": 0, "RowsSuperseded": 0 }))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **ინკრემენტალური წაკითხვა**

# CELL ********************

df = (spark.table(BRONZE_TABLE)
      .filter((F.col("LastModifiedTime") > F.lit(last_wm))
            & (F.col("LastModifiedTime") <= F.lit(upper_wm)))) 
rows_read = df.count()
print("Current batch rows:", rows_read)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **სვეტებისა და ცარიელი მნიშვნელობების ნორმალიზაცია**

# CELL ********************

df = df.toDF(*[c.strip().lower() for c in df.columns])
text_cols   = [c for c, t in df.dtypes if t == "string"]
null_tokens = ["", "null", "n/a", "na", "none", "-"]
df = df.withColumns({
    c: F.when(F.lower(F.trim(F.col(c))).isin(null_tokens), F.lit(None).cast("string"))
        .otherwise(F.trim(F.col(c)))
    for c in text_cols })


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **11. Header სტრიქონების გამოყოფა**

# CELL ********************

header_condition = (
    (F.lower(F.col("transactionid")) == "transactionid")
    | (F.lower(F.col("linenumber")) == "linenumber")
    | (F.lower(F.col("quantity")) == "quantity") )
df_header = df.filter(header_condition).withColumn("RejectReason", F.lit("HEADER_ROW"))
df = df.filter(~header_condition | header_condition.isNull())


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **12. რიცხვების, ფასდაკლების და თარიღის ტიპიზაცია**

# CELL ********************

# 12.1 რაოდენობა სიტყვებით
quantity_map  = {"one": "1", "two": "2", "three": "3", "four": "4", "five": "5"}
quantity_expr = F.create_map(*[F.lit(x) for kv in quantity_map.items() for x in kv])
df = (df
    .withColumn("quantity",
        F.coalesce(quantity_expr[F.lower(F.col("quantity"))], F.col("quantity")))
    .withColumn("line_no_clean",      F.expr("try_cast(linenumber AS INT)"))
    .withColumn("quantity_clean",     F.expr("try_cast(quantity AS INT)"))
    .withColumn("unit_price_clean",
        F.expr("try_cast(replace(unitprice, ',', '.') AS DECIMAL(18,2))"))
    .withColumn("total_amount_clean",
        F.expr("try_cast(replace(totalamount, ',', '.') AS DECIMAL(18,2))")) )
# 12.2 ფასდაკლება: "10%", "10", "0.10" -> 0.10
discount_raw = F.expr("try_cast(replace(replace(discount, '%', ''), ',', '.') AS DECIMAL(18,4))")
df = df.withColumn(
    "discount_clean",
    F.when(discount_raw > 1, discount_raw / 100).otherwise(discount_raw).cast("DECIMAL(18,4)") )
# 12.3 თარიღი: შერეული ფორმატები
date_formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "dd/MM/yyyy HH:mm:ss",
                "yyyy.MM.dd HH:mm:ss", "yyyy-MM-dd", "dd-MM-yyyy", "dd/MM/yyyy"]
df = df.withColumn(
    "transaction_ts",
    F.coalesce(*[F.try_to_timestamp(F.col("transactiondatetime"), F.lit(fmt))
                 for fmt in date_formats]) )


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **13. მაღაზიისა და გადახდის მეთოდის სტანდარტიზაცია**

# CELL ********************

store_digits = F.regexp_extract(F.upper(F.col("storeid")), r"(\d+)", 1)
payment      = F.lower(F.col("paymentmethod"))
df = (df
    .withColumn("store_id_clean",
        F.when(store_digits != "", F.concat(F.lit("ST"), F.lpad(store_digits, 3, "0"))))
    .withColumn("payment_method_clean",
        F.when(payment.isin("cash", "csh", "ნაღდი"), "CASH")
         .when(payment.isin("card", "visa", "mastercard", "debit card", "credit card", "ბარათი"), "CARD")
         .when(payment.isin("mobile", "mobile pay", "apple pay", "google pay"), "MOBILE")
         .when(payment.isin("bank transfer", "transfer", "bt"), "BANK_TRANSFER")) )


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# **14. Deduplication: თითოეული RowID-ის ბოლო ვერსია**

# CELL ********************


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
