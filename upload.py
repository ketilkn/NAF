import argparse
import requests
import sys
import pathlib
import yaml
import logging

import session

LOG = logging.getLogger("glicko")


def upload_file(csv_file, url, secret=False):
    LOG.debug('Connecting to %s', url)
    header = session.build_header()
    form = {'submit': 'submit'}
    if secret:
        form['top_secret'] = secret

    LOG.info('Uploading file')
    response = requests.post(url, files={'csv_file': csv_file}, headers=header, data=form)
    if not response:
        LOG.error('Problem uploading file %s %s', response.status_code, response.reason)
        LOG.debug('%s', response.text)
        return False
    if "Done" not in response.text:
        LOG.error('Server returned %s, but a confirmation of the upload was not found', response.status_code)
        LOG.error(response.text)
        return False
    if "SQLSTATE" in response.text:
        LOG.warning('Server returned %s and Done. Found SQLSTATE. That could be a problem', response.status_code)
        LOG.warning(response.text)
        return True

    LOG.info('Upload OK!')
    return True


def upload_rank(file, secret=False, url='https://member.thenaf.net/glicko/import.php'):
    LOG.debug('Uploading %s to %s', file.name, url)

    if not file:
        LOG.error('Error loading file %s', file.name)
        return False

    response = upload_file(file, url, secret)
    file.close()

    if not response:
        return False
    return True


def main():
    log_format = "[%(levelname)s:%(filename)s:%(lineno)s - %(funcName)20s ] %(message)s"
    logging.basicConfig(level=logging.INFO if "--debug" not in sys.argv else logging.DEBUG, format=log_format)

    config = {'target_url': 'http://example.com/ranks.php',
              'top_secret': 'no secret'}
    if pathlib.Path('upload.yml').is_file():
        with open('upload.yml', 'r') as config_file:
            config.update(yaml.safe_load(config_file))

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('--debug', action='store_true')
    arg_parser.add_argument('infile', type=argparse.FileType('r'))
    arg_parser.add_argument('--target-url', default=config['target_url'])
    arg_parser.add_argument('--top-secret', default=config['top_secret'])

    arguments = arg_parser.parse_args()

    LOG.debug("Using arguments %s", arguments)
    return upload_rank(file=arguments.infile, url=arguments.target_url, secret=arguments.top_secret)


if __name__=='__main__':
    if not main():
        sys.exit(74)
