import os
from multiprocessing import Process

from flask import Flask, request, jsonify
from flask_cors import CORS
from json2html import *

from send_mail import MailSender, MailReceiver

app = Flask(__name__)
cors = CORS(app, resources={r"/*": {"origins": "*"}})


@app.route('/form/submission', methods=['POST'])
def return_status():
    request_json = request.json

    message_sender = MailSender()

    # Send both messages in parallel
    p1 = Process(target=send_message_to_consignor, args=(message_sender, request_json))
    p2 = Process(target=send_message_to_receiver, args=(message_sender, request_json))
    p1.start()
    p2.start()

    # wait until both messages are sent
    p1.join()
    p2.join()

    response = {'status': 'success'}
    return jsonify(response)


def send_message_to_consignor(message_sender: MailSender, request_json):
    receiver = request_json['message']['Mail']
    subject = "Cevi Züri 11 | Bestätigung Kontaktformular"
    msg = "Danke für deine Nachricht: " + json2html.convert(json=request_json)
    message_sender.send_message(receiver, subject, msg)


def send_message_to_receiver(message_sender: MailSender, request_json):
    receiver = MailReceiver[request_json['receiver']]
    subject = "Cevi Züri 11 | Nachricht via Kontaktformular"
    msg = "Neue Nachricht: " + json2html.convert(json=request_json)
    message_sender.send_message(receiver, subject, msg)


if __name__ == "__main__":
    PORT = int(os.environ.get("PORT", 5000))
    app.run(debug=(os.environ.get("DEBUG", "False").lower() in ('true', '1', 't')), host="0.0.0.0",
            port=int(os.environ.get("PORT", PORT)))
