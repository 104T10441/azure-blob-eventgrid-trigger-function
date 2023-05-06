import logging
import json
import datetime

import azure.functions as func

def main(event: func.EventGridEvent, miztProc: func.InputStream, outputBlob: func.Out[str], context: func.Context) -> None:
# def main( req: func.HttpRequest, miztProc: func.InputStream, outputBlob: func.Out[str], context: func.Context) -> func.HttpResponse:
    get_req_body = None
    body_blob_name = None
    recv_blob_name = None
    _d={}
    try:
        result = {
            "id": event.id,
            "data": event.get_json(),
            "topic": event.topic,
            "subject": event.subject,
            "event_type": event.event_type,
        }

        logging.info(f"Python EventGrid trigger processed an event: {json.dumps(result)}" )
    
        # query_blob_name = req.params.get("blob_name") # For query string
        # # For blob_name in body
        # get_req_body = req.get_json()
        # body_blob_name = get_req_body.get("blob_name")

        # if query_blob_name:
        #     recv_blob_name = query_blob_name
        # elif body_blob_name:
        #     recv_blob_name = body_blob_name

        # logging.info(f" Received Blob Name: {recv_blob_name}")
        _d = miztProc.read().decode("utf-8")
        _d = json.loads(_d)
        blob_url = result['data']['url']
        blob_name = blob_url.split('/')[-1]
        _d["blob_name"] = blob_name
        _d["miztiik_event_processed"] = True
        _d["last_processed_on"] = datetime.datetime.now().isoformat()
        logging.info(f"BLOB DATA: {json.dumps(_d)}")
        outputBlob.set(str(_d)) # Imperative to type cast to str
        logging.info(f"Uploaded to blob storage")

    except Exception as e:
        logging.exception(f"ERROR:{str(e)}")

