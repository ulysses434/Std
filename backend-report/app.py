from flask import Flask, jsonify
import os
import logging
import requests
import pymongo
from apscheduler.schedulers.background import BackgroundScheduler

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

REPORT_URL = os.environ.get(
    'REPORT_URL',
    'https://d5dg7f2abrq3u84p3vpr.apigw.yandexcloud.net/report'
)
DB = os.environ.get('DB') or "mongodb://localhost:27017/test"

client = pymongo.MongoClient(DB, serverSelectionTimeoutMS=5000)
parsedUri = pymongo.uri_parser.parse_uri(DB)
db = client[parsedUri['database']]


@app.route('/health')
@app.route('/')
def home():
    return jsonify("I'm alive")


def load_report():
    try:
        response = requests.get(REPORT_URL, timeout=10)
        response.raise_for_status()
        db.reports.insert_one(response.json())
        logging.info("Inserted a new report to the database: %s", response.text)
    except Exception as e:
        logging.warning("Не удалось загрузить отчёт: %s", e)


if __name__ == "__main__":
    sched = BackgroundScheduler(daemon=True)
    sched.add_job(load_report, 'interval', minutes=5)
    sched.start()
    load_report()
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, use_reloader=False)
