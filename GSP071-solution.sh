##
## GSP071 BigQuery: Qwik Start - Command Line
##

#Fix tabular output
gcloud config set accessibility/screen_reader false

#Set Important Vars
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"
export ZONE="us-central1-a"
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Show starting resources
gcloud compute networks list
gcloud compute networks subnets list
gcloud compute firewall-rules list
gcloud compute instances list


# Task 1 - Examine a table
bq show bigquery-public-data:samples.shakespeare

# Task 2 - Run the help command
bq help query

# Task 3 - Run a query
bq query --use_legacy_sql=false \
'SELECT
   word,
   SUM(word_count) AS count
 FROM
   `bigquery-public-data`.samples.shakespeare
 WHERE
   word LIKE "%raisin%"
 GROUP BY
   word'

bq query --use_legacy_sql=false \
'SELECT
   word
 FROM
   `bigquery-public-data`.samples.shakespeare
 WHERE
   word = "huzzah"'

# Task 4 - Create a new table
bq ls
bq ls bigquery-public-data:
bq mk babynames
bq ls

curl -LO http://www.ssa.gov/OACT/babynames/names.zip
ls
unzip names.zip
ls
bq load babynames.names2010 yob2010.txt name:string,gender:string,count:integer
bq ls babynames
bq show babynames.names2010

# Task 5 - Run queries
bq query "SELECT name,count FROM babynames.names2010 
WHERE gender = 'F' ORDER BY count DESC LIMIT 5"
bq query "SELECT name,count FROM babynames.names2010 
WHERE gender = 'M' ORDER BY count ASC LIMIT 5"

#Task 7 - Cleanup
bq rm -r babynames
