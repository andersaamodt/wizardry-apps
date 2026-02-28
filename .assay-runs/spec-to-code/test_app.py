import unittest
from app import app, allowed_file, UPLOAD_FOLDER

class TestFileUpload(unittest.TestCase):
    def setUp(self):
        app.config['TESTING'] = True
        self.app = app.test_client()

    def test_upload_valid_file(self):
        response = self.app.post('/upload', data={'file': ('test.txt', 'test.txt', 'text/plain')})
        self.assertEqual(response.status_code, 200)
        self.assertIn('filename', response.json)

    def test_upload_no_file(self):
        response = self.app.post('/upload')
        self.assertEqual(response.status_code, 400)

    def test_upload_invalid_file(self):
        with open('test.pdf', 'rb') as f:
            file_data = f.read()
        response = self.app.post('/upload', data={'file': ('test.pdf', file_data, 'application/pdf')})
        self.assertEqual(response.status_code, 400)

if __name__ == '__main__':
    unittest.main()
