from __future__ import annotations

import base64
import json
import os.path
from email.mime.text import MIMEText
from enum import Enum
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

CLIENT_TOKEN_FILE = 'token/token.json'
CLIENT_CREDENTIALS_FILE = 'credentials/credentials.json'
SECRET_DIRECTORY = './secrets/'
MAIL_CONFIG = './config/mail_config.json'
SCOPES = ['https://www.googleapis.com/auth/gmail.compose', 'https://www.googleapis.com/auth/gmail.send']


class MailReceiver(str, Enum):
    DEFAULT = 'default_receiver'


class MailSender:

    def __init__(self):

        with open(MAIL_CONFIG, 'r') as mail_config:
            self.mail_config = json.load(mail_config)
            print(f'Config: {self.mail_config}')

        creds = None

        # The file token.json stores the user's access and refresh tokens, and is
        # created automatically when the authorization flow completes for the first
        # time.
        if os.path.exists(SECRET_DIRECTORY + CLIENT_TOKEN_FILE):
            creds = Credentials.from_authorized_user_file(SECRET_DIRECTORY + CLIENT_TOKEN_FILE, SCOPES)

        # If there are no (valid) credentials available, let the user log in.
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(SECRET_DIRECTORY + CLIENT_CREDENTIALS_FILE, SCOPES)
                creds = flow.run_local_server(port=0)

                # Save the credentials for the next run
                with open(SECRET_DIRECTORY + CLIENT_TOKEN_FILE, 'w') as token:
                    token.write(creds.to_json())

        self.service = build('gmail', 'v1', credentials=creds)

    def send_message(self, receiver: MailReceiver | str, subject: str, msg: str):

        try:
            message = MIMEText(msg, 'html')
            message['To'] = self.mail_config[receiver] if receiver in self.mail_config else receiver
            message['From'] = self.mail_config['dispatcher_address']
            message['Subject'] = subject

            # encoded message
            encoded_message = base64.urlsafe_b64encode(message.as_bytes()).decode()
            create_message = {'message': {'raw': encoded_message}}

            # Create and send message
            draft = self.service.users().drafts().create(userId="me", body=create_message).execute()
            message = self.service.users().drafts().send(userId="me", body=draft).execute()

            print(f'Message Send: {message["id"]}')

        except HttpError as error:
            print(f'An error occurred: {error}')
            send_message = None
            return send_message


if __name__ == '__main__':
    message_sender = MailSender()
