import json
import boto3
import logging

# Setting up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Creating an S3 resource
    s3 = boto3.resource('s3', endpoint_url='http://localhost:4566')
    # Defining source and destination bucket names
    source_bucket_name = 's3-beginning'
    destination_bucket_name = 's3-end'
    
    # Accessing the source bucket
    source_bucket = s3.Bucket(source_bucket_name)

    logger.info("Received event: %s", json.dumps(event))

    try:
        # Checking if the event contains 'Records' field
        if 'Records' not in event:
            raise ValueError("Event does not contain 'Records' field")

        # Iterating through each record in the event
        for record in event['Records']:
            if 'Sns' in record:
                # If the record is an SNS message, extract the message
                sns_message = json.loads(record['Sns']['Message'])
                logger.info("SNS message: %s", json.dumps(sns_message))
                s3_event = sns_message
            else:
                s3_event = record

            # Iterating through each S3 record in the event
            for s3_record in s3_event.get('Records', []):
                # Extracting the key of the object
                key = s3_record['s3']['object']['key']
                logger.info("Processing file: %s from bucket: %s", key, source_bucket_name)
                
                # Defining the copy source and destination
                copy_source = {'Bucket': source_bucket_name, 'Key': key}
                destination_file_name = key  # Keeping the same file name in the destination bucket
                
                # Copying the object from source to destination bucket
                s3.meta.client.copy(copy_source, destination_bucket_name, destination_file_name)

        # Returning success response
        return {'statusCode': 200, 'body': 'Files copied successfully'}
    except Exception as e:
        # Logging and returning error response
        logger.error("Error processing event: %s", e)
        return {'statusCode': 500, 'body': 'Error copying files'}
