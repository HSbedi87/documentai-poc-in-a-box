import mock
import os

import main

def test_print(capsys):
    name = '11409817473929939778/3007484672167903232.json'
    event = {
        'bucket': 'northam-ce-mlai-dai-hitl-output',
        'name': name,
        'metageneration': 'some-metageneration',
        'timeCreated': '0',
        'updated': '0',
        'contentType': 'application/json'
    }

    os.environ["DEBUSSY"] = "1"
    os.environ["PROCESSOR_EXTRACT_FIRESTORE_COLLECTION"] = "invoice_extractions"
    os.environ["COMPILED_RESULTS_FIRESTORE_COLLECTION"] = "docai-processor-extract-collection"

    context = mock.MagicMock()
    context.event_id = 'some-id'
    context.event_type = 'gcs-event'

    # Call tested function
    main.main_func(event, context)
    out, err = capsys.readouterr()
    # assert 'File: {}\n'.format(name) in out