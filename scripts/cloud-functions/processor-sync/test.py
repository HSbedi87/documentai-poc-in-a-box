import mock
import os

import main

def test_print(capsys):
    name = 'sample_invoice.pdf'
    event = {
        'bucket': 'northam-ce-mlai-dai-ingest',
        'name': name,
        'metageneration': 'some-metageneration',
        'timeCreated': '0',
        'updated': '0',
        'contentType': 'application/pdf'
    }

    os.environ["DEBUSSY"] = "1"
    os.environ["PROJECT_ID"] = "dai-pipeline"
    os.environ["PROJECT_NUM"] = "790941301722"
    os.environ["LOCATION"] = "us"

    os.environ["SKIP_HITL"] = "yes"
    os.environ["HITL_BUCKET"] = "dai-pipeline-dai-hitl-output"

    context = mock.MagicMock()
    context.event_id = 'some-id'
    context.event_type = 'gcs-event'

    # Call tested function
    main.main_func(event, context)
    out, err = capsys.readouterr()
    # assert 'File: {}\n'.format(name) in out