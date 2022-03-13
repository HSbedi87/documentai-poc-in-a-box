import os, datetime
from google.cloud import firestore

#add document to firestore collection

def create_firestore_doc(firestore_collection,doc_name, doc_object):
    db = firestore.Client()

    print(f'Adding doc ({doc_name}) to firestore collection ({firestore_collection})')

    doc_ref = db.collection(firestore_collection).document(doc_name)
    doc_ref.set(doc_object)
    # doc_ref.set({
    #     u'first': u'Ada',
    #     u'last': u'Lovelace',
    #     u'born': 1815
    # })