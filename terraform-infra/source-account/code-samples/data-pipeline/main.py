import random
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("🔔 Test Lambda started")

    # Simulate some "work"
    users_processed = random.randint(1, 50)

    # Emit a structured metric
    logger.info(
        json.dumps(
            {
                "function": "test-lambda",
                "metric": "users_processed",
                "value": users_processed,
            }
        )
    )

    # Emit a structured log (non-metric)
    logger.info(
        json.dumps(
            {
                "function": "test-lambda",
                "log": "operation_complete",
                "details": {"processed": users_processed},
            }
        )
    )

    logger.info("✅ Test Lambda finished")

    return {"statusCode": 200, "body": json.dumps({"processed": users_processed})}
