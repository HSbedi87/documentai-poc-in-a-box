import os, datetime
from google.cloud import firestore

#add document to firestore collection

def create_firestore_doc(firestore_collection,doc_name, doc_object):
    db = firestore.Client()

    print(f'Adding doc ({doc_name}) to firestore collection ({firestore_collection})')

    doc_ref = db.collection(firestore_collection).document(doc_name)
    doc_ref.set(doc_object)


def get_firestore_doc(firestore_collection, hitl_operation_id):
    fsclient = firestore.Client()
    fscollection = fsclient.collection(firestore_collection)

    doc = fscollection.where('hitl_operation_id', '==', hitl_operation_id).get()

    return doc

def parse_firestore_doc(firestore_doc):
    doc_snap = firestore_doc.pop()
    entities = doc_snap.get('entities')
    source_extraction_file = doc_snap.get('file_name')

    return entities, source_extraction_file