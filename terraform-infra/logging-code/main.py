import logging

logger = logging.getLogger()  # for lambda -> it seems default logging is set
# https://docs.aws.amazon.com/lambda/latest/dg/python-logging.html


def handler(event, context):
    print("This is a lambda to test logging in the cloudwatch alarms")
    logger.debug("debug log")
    logger.warning("warning log")
    logger.error("error log")
    logger.info("info log")
    logger.critical("critical log")
