from flask import Flask, request, send_file, jsonify
from flask_cors import CORS

app = Flask(__name__)
cors = CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/form/submission', methods=['POST'])
def return_status():

    # TODO: send mail with message
    print(request.json)

    response = {'status': 'success'}
    return jsonify(response)

if __name__ == "__main__":
    app.run(debug=(os.environ.get("DEBUG", "False").lower() in ('true', '1', 't')), host="0.0.0.0",
            port=int(os.environ.get("PORT", 8080)))