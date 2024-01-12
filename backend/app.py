import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from multiprocessing import Process

from send_mail import MailSender, MailReceiver

app = Flask(__name__)
cors = CORS(app, resources={r"/*": {"origins": "*"}})


@app.route('/form/submission', methods=['POST'])
def return_status():
    request_json = request.json
    print(f"Received request: {request_json}")
    print(request_json)

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


def format_to_text(json: any, indent=0) -> str:
    """
    Convert json to human-readable text
    """

    if json == 'true' or json == 'false':
        json = json == 'true'

    # check if it's a bool
    if isinstance(json, bool):
        return 'angewählt' if json else 'nicht angewählt'

    # check if json is a string or a json object
    if isinstance(json, str):
        return json

    # recursively convert json to text
    text = "<br>"
    for key, value in json.items():
        text += "&emsp;" * indent
        text += f'<b>{key}</b>: {format_to_text(value, indent + 1)}' + "<br>"
    return text


def send_message_to_consignor(message_sender: MailSender, request_json):
    receiver = request_json['message']['Mail']
    subject = "Cevi Züri 11 | Bestätigung Kontaktformular"
    name = request_json['message']['Vorname'] if 'Vorname' in request_json['message'] else ''
    msg = f"Lieber {name}<br><br>Vielen Dank für deine Anfrage, du wirst in Kürze von uns hören.<br><br>Liebe " \
          f"Grüsse<br>Cevi Züri 11 Team<br><br> Deine Nachricht:" + format_to_text(json=request_json['message'])
    message_sender.send_message(receiver, subject, msg)


def send_message_to_receiver(message_sender: MailSender, request_json):
    subject = "Cevi Züri 11 | Nachricht via Kontaktformular"
    msg = "Neue Nachricht von der Webseite: <br>" + format_to_text(json=request_json)
    message_sender.send_message(request_json['receiver'], subject, msg, request_json['message']['Mail'])


if __name__ == "__main__":
    PORT = int(os.environ.get("PORT", 5000))
    app.run(debug=(os.environ.get("DEBUG", "False").lower() in ('true', '1', 't')), host="0.0.0.0",
            port=int(os.environ.get("PORT", PORT)))
