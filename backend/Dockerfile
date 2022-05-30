FROM python:3.9

WORKDIR /app

# Install requirements
COPY ./requirements.txt /app
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app

RUN chmod +x ./docker-entrypoint.sh
CMD exec gunicorn --workers 1 --threads 1 --timeout 120 --reload --bind :$PORT app:app