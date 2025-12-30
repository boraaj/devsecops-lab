from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import boto3
from botocore.exceptions import ClientError
import os

# App initialization
app = FastAPI(title="DevSecOps Lab API")
REGION = os.getenv("AWS_REGION", "eu-west-3")
TABLE_NAME = os.getenv("DYNAMODB_TABLE", "devsecops-items")

# The entity DynaoDB Table
dynamodb = boto3.resource('dynamodb', region_name=REGION)

# The table name I created
table_name = dynamodb.Table(TABLE_NAME)# Must match with Terraform

# The table in AWS
table = dynamodb.Table(table_name)

## Pydantic Basic Validation ##
class Item(BaseModel):
    id: str
    name: str
    description: str = None


# -- Endpoints -- 

@app.get("/")
def read_root():
    return {"status": "ok", "message": "DevSecOps Lab is Running!"}

@app.post("/items/")
def create_item(item: Item):
    """Stores an item in the DynamoDB Table"""
    try:
        table.put_item(Item=item.dict())
        return {"message": "Item stored successfully", "item": item}
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/items/{item_id}")
def read_item(item_id: str):
    """Read an item from the DynamoDB Table"""
    try:
        response = table.get_item(Key={'id': item_id})
        item = response.get('Item')
        if not item:
            raise HTTPException(status_code=404, detail="Item no encontrado")
        return item
    except ClientError as e:
        raise HTTPException(status_code=500, detail=str(e))