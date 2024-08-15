#!/bin/bash

# Configurar credenciales ficticias
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_SDK_LOAD_CONFIG=false

echo "LocalStack está listo. Creando recursos..."

# Crear la cola SQS
aws --endpoint-url=http://host.docker.internal:4566 sqs create-queue --queue-name message-to-sqs.fifo --attributes FifoQueue=true

# Crear la función Lambda para enviar mensajes a SQS
aws --endpoint-url=http://host.docker.internal:4566 lambda create-function --function-name myLambda \
--runtime python3.8 \
--role arn:aws:iam::000000000000:role/lambda-role \
--handler create_lambda_function.lambda_handler \
--zip-file fileb:///scripts/create_lambda_function.zip \
--environment Variables="{QUEUE_NAME=message-to-sqs.fifo, ENDPOINT_URL=http://host.docker.internal:4566}" \
--timeout 30

# Configurar la API Gateway
API_ID=$(aws --endpoint-url=http://host.docker.internal:4566 apigateway create-rest-api --name 'MyAPI' --query 'id' --output text)
if [ -z "$API_ID" ]; then
  echo "Error creando la API Gateway"
  exit 1
fi
echo "API_ID: $API_ID"

RESOURCE_ID=$(aws --endpoint-url=http://host.docker.internal:4566 apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)
if [ -z "$RESOURCE_ID" ]; then
  echo "Error obteniendo el recurso de la API Gateway"
  exit 1
fi
echo "RESOURCE_ID: $RESOURCE_ID"

# Crear un nuevo recurso /send-message
SEND_MESSAGE_RESOURCE_ID=$(aws --endpoint-url=http://host.docker.internal:4566 apigateway create-resource --rest-api-id $API_ID --parent-id $RESOURCE_ID --path-part send-message --query 'id' --output text)
if [ -z "$SEND_MESSAGE_RESOURCE_ID" ]; then
  echo "Error creando el recurso send-message en API Gateway"
  exit 1
fi
echo "SEND_MESSAGE_RESOURCE_ID: $SEND_MESSAGE_RESOURCE_ID"

aws --endpoint-url=http://host.docker.internal:4566 apigateway put-method --rest-api-id $API_ID --resource-id $SEND_MESSAGE_RESOURCE_ID --http-method POST --authorization-type "NONE"
aws --endpoint-url=http://host.docker.internal:4566 apigateway put-integration --rest-api-id $API_ID --resource-id $SEND_MESSAGE_RESOURCE_ID --http-method POST --type AWS_PROXY --integration-http-method POST --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:myLambda/invocations"

aws --endpoint-url=http://host.docker.internal:4566 lambda add-permission --function-name myLambda --statement-id apigateway-test-2 --action "lambda:InvokeFunction" --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:us-east-1:000000000000:$API_ID/*/POST/send-message"

aws --endpoint-url=http://host.docker.internal:4566 apigateway create-deployment --rest-api-id $API_ID --stage-name test

echo "Recursos creados. LocalStack está listo."

echo "YOUR_REST_API_ID: $API_ID"
echo "RESOURCE_ID: $RESOURCE_ID"
echo "SEND_MESSAGE_RESOURCE_ID: $SEND_MESSAGE_RESOURCE_ID"

# Mantener el contenedor en ejecución (opcional, si es necesario)
tail -f /dev/null