import boto3
import json

# Initialize DynamoDB resource and table
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloudresume-test')

def lambda_handler(event, context):
    try:
        # Attempt to update the visitor count
        dynamodbResponse = table.update_item(
            Key={
                'id': 'visitor_count'
            },
            UpdateExpression='SET visitors = visitors + :val1',
            ExpressionAttributeValues={
                ':val1': 1
            },
            ReturnValues='UPDATED_NEW'
        )
        
        # If update successful, prepare response with updated count
        responseBody = json.dumps({"count": int(dynamodbResponse['Attributes']['visitors'])})

    except:
        # If update fails (item not found), create a new item and set visitor count to 1
        putItem = table.put_item(
            Item={
                'id': 'visitor_count',
                'visitors': 1
            }
        )

        # Retrieve the newly created item
        dynamodbResponse = table.get_item(
            Key={
                'id': 'visitor_count',
            }
        )

        # Prepare response with initial count (1 in this case)
        responseBody = json.dumps({"count": int(dynamodbResponse['Item']['visitors'])})

    # Prepare API response
    apiResponse = {
        "isBase64Encoded": False,
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "https://cloudresume.leechih.us", 
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
        },
        "body": responseBody
    }

    return apiResponse
