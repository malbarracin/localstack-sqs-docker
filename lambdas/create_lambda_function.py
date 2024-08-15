import boto3
import os
import json
from pymongo import MongoClient
from bson.objectid import ObjectId
from datetime import datetime

def lambda_handler(event, context):
    try:
        # Inicializamos Variables

        path = event['path']
        print("Event: ", event)
        print("Path: ", path)

        timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")

        errors = [
            {
                "code": "500",
                "message": "System Events Unavailable"
            }
        ]

        error={
            "timestamp": timestamp,
            "path": path,
            "description": "System Events Unavailable",
            "errors": errors
        }
        bodyResponseErrorStr = json.dumps(error)

        # Configuración de MongoDB
        mongo_uri = os.environ.get('MONGO_URI', 'mongodb://root:root@mongo-dev:27017')
        db_name = os.environ.get('DATA_BASE_NAME', 'sqs_status')
        collection_name = os.environ.get('COLLECTION_NAME', 'messages')

        print("Conectando a MongoDB...")
        

        # Conectar a MongoDB
        try:
            client = MongoClient(mongo_uri)
            db = client[db_name]
            collection = db[collection_name]
            print("Conectado a MongoDB y obteniendo la colección...")
        except ConnectionError as e:
            # Capturar errores de conexión específicos
            print("Error de conexión a MongoDB:", e)
            return {
                "isBase64Encoded": 'false',
                "statusCode": 500,
                "body": bodyResponseErrorStr
            }
        except Exception as ex:
            # Capturar otras excepciones generales
            print("Ocurrió un error:", ex)
            return {
                "isBase64Encoded": 'false',
                "statusCode": 500,
                "body": bodyResponseErrorStr
            }

        print(json.dumps(event['body']))
        objeto_json = json.loads(event['body'])
        print(json.dumps(objeto_json))

        eventId=event['requestContext']['requestId']
        print("EventId: ", eventId)
        fecha_iso8601 = datetime.now().isoformat()
        creationDate = datetime.strptime(fecha_iso8601, "%Y-%m-%dT%H:%M:%S.%f")
        
        statusHistoryPending = [{
            "creationDate": creationDate,
            "status": "PENDING",
            "stage": "INITIAL"
        }]  

        bodyMongo = {
            "eventId": eventId,
            "creationDate": creationDate,
            "apiRequest": json.dumps(objeto_json),
            "retries": 0,
            "statusHistory": statusHistoryPending    
        }
        
        print("BodyMongo Pending: ", bodyMongo)

        try:
            # Crear un nuevo registro en la base de datos
            record_id = collection.insert_one(bodyMongo).inserted_id
            print("Record ID: {}...".format(record_id))
        except Exception as ex:
            # Capturar otras excepciones generales
            print("Ocurrió un error:", ex)
            return {
                "isBase64Encoded": 'false',
                "statusCode": 500,
                "body": bodyResponseErrorStr
            }

        # Obtener el endpoint URL desde las variables de entorno
        endpoint_url = os.environ.get('ENDPOINT_URL', 'http://localhost:4566')
        queue_name = os.environ['QUEUE_NAME']
        
        # Crear el cliente de SQS
        sqs = boto3.client('sqs', endpoint_url=endpoint_url, region_name='us-east-1')
        
        # Obtener la URL de la cola
        queue_url = sqs.get_queue_url(QueueName=queue_name)['QueueUrl']
        
        # Enviar el mensaje a la cola SQS con el ID del registro en MongoDB
        message_body = {
            "mongo_record_id": str(record_id),
            "event": event
        }
        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message_body),
            MessageGroupId="default",
            MessageDeduplicationId=str(record_id)  # Usa un ID único para la deduplicación
        )
        
        # Actualizar el registro en MongoDB con el estado enviado
        collection.update_one({"_id": ObjectId(record_id)}, {"$set": {"status": "INIT"}})

        return {
            'isBase64Encoded': False,
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Message sent to SQS and MongoDB record created',
                'sqs_response': response,
                'mongo_record_id': str(record_id)
            })
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'isBase64Encoded': False,
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e)
            })
        }
