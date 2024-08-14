cd lambdas/

docker build -t my-lambda-function -f Dockerfile.create_lambda_function .


zip create_lambda_function.zip create_lambda_function.py
mv create_lambda_function.zip ../scripts/


mkdir package
cd package
cp -r ../../venv/Lib/site-packages/* .
cp ../create_lambda_function.py .
zip -r9 ../../scripts/create_lambda_function.zip .



echo "Buildeaste todo maquina"
cd ../../..