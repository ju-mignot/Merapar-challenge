import os
import boto3

ssm = boto3.client("ssm")

def get_dyn_str():
    resp = ssm.get_parameter(Name="merapar_challenge-dynamic_string", WithDecryption=False)
    return resp["Parameter"]["Value"]

def handler(event, context):
    dynamic_str = get_dyn_str()
    html = f"<html><head><title>Dynamic String</title></head><body><h1>The saved string is {dynamic_str}</h1></body></html>"
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html"},
        "body": html
    }
