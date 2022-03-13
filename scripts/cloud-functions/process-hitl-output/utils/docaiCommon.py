import datetime
import re

from google.cloud import documentai_v1 as documentai
from google.cloud import storage



def process_doc_sync(gcs_blob, content_type, project_number, location, dai_processor_id, skip_human_review):
    documentai_client = documentai.DocumentProcessorServiceClient()

    document = {
        "content": gcs_blob,
        "mime_type": content_type
    }

    invoice_processor = f"projects/{project_number}/locations/{location}/processors/{dai_processor_id}"

    request = {
        "name": invoice_processor,
        "raw_document": document,
        "skip_human_review": skip_human_review
    }

    results = documentai_client.process_document(request)
    print(f'HITL Output: {results.human_review_status}')

    hitl_op = results.human_review_status.human_review_operation
    hitl_op_split = hitl_op.split('/')
    hitl_op_id = hitl_op_split.pop()

    results_json = documentai.types.Document.to_json(results.document)

    return results.document, hitl_op_id, results_json


def extract_specialized_entities(doc):
    # entity_dict = dict()
    # ent_id, conf, mention_text, type_ = None
    entity_list = dict()
    # for entity in doc.entities:
    # ents = {
    # entity.type_: entity.mention_text,
    # "confidence": entity.confidence
    # }
    # entity_list.append(ents)

    # entity_list2 = list()
    for entity in doc.entities:
        if entity.type_ == 'line_item' or entity.type_ == 'vat':
            for property in entity.properties:
                ents = {
                    "type_": property.type_,
                    "mention_text": property.mention_text,
                    "confidence": property.confidence,
                    "normalized_text": property.normalized_value.text
                }
                entity_list[property.id] = ents
            ents = {
                "type_": entity.type_,
                "mention_text": entity.mention_text,
                "confidence": entity.confidence,
                "normalized_text": entity.normalized_value.text
            }
            entity_list[entity.id] = ents
        else:
            ents = {
                "type_": entity.type_,
                "mention_text": entity.mention_text,
                "confidence": entity.confidence,
                "normalized_text": entity.normalized_value.text
            }
            entity_list[entity.id] = ents

    return entity_list


def save_extract_to_gcs(dest_bucket, content, filename, eventid, hitl_operation_id):
    storageclient = storage.Client()
    bucket = storageclient.get_bucket(dest_bucket)

    fname = f'{filename.split(".")[0]}-{eventid}.json'

    # response_doc = {'document': content}

    write_file = bucket.blob(fname)
    write_file.metadata = {'hitl_operation_id': hitl_operation_id}
    write_file.upload_from_string(format(content), content_type='application/json')
    fpath = f'gs://{dest_bucket}/{fname}'
    return fpath

def extract_entities_from_output_json(output_json_path):
    storage_client = storage.Client()
    match = re.match(r"gs://([^/]+)/(.+)", output_json_path)
    output_bucket = match.group(1)
    prefix = match.group(2)
    bucket = storage_client.get_bucket(output_bucket)
    blob_list = list(bucket.list_blobs(prefix=prefix))
    entity_list_merged = dict()

    for blob in blob_list:
        if ".json" in blob.name:
            blob_as_bytes = blob.download_as_string()
            document = documentai.types.Document.from_json(blob_as_bytes)
            entity_list = extract_specialized_entities(document)
            entity_list_merged |= entity_list

    return entity_list
#