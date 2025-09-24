import base64
import json


def handler(event, context):
    output = []
    print(event)
    for record in event["records"]:
        try:
            # Decode the base64 payload
            payload = base64.b64decode(record["data"]).decode("utf-8")

            # Example transformation: wrap into JSON
            transformed = json.dumps({"original_message": payload})

            result = {
                "recordId": record["recordId"],
                "result": "Ok",
                "data": base64.b64encode(transformed.encode("utf-8")).decode("utf-8"),
            }

        except Exception:
            # If anything fails, mark record as failed
            result = {
                "recordId": record["recordId"],
                "result": "ProcessingFailed",
                "data": record["data"],  # pass original back
            }

        output.append(result)

    return {"records": output}
