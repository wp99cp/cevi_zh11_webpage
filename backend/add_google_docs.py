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
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']



class SpreadSheetAdder:

    def __init__(self, spreadsheetId: str) -> None:

        self.spreadsheetId = spreadsheetId
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

        self.service = build("sheets", "v4", credentials=creds)

    def add_row(self, values: List[str]):

        # we need a 2D array
        values = [values]

        try:

            body = {"values": values}
            value_input_option = "USER_ENTERED"

            result = (
                service.spreadsheets()
                .values()
                .append(
                    spreadsheetId=self.spreadsheetId,
                    valueInputOption=value_input_option,
                    body=body,
                )
                .execute()
            )
            print(f"{(result.get('updates').get('updatedCells'))} cells appended.")

        except HttpError as error:
            print(f'An error occurred: {error}')
            send_message = None
            return send_message


if __name__ == '__main__':
    message_sender = MailSender()
