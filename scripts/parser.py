from sys import argv
import argparse


class Parser:
    def __init__(self, target, data):
        self.target = target
        self.params_raw = data

        
    def create_params(self):
        self.parser = argparse.ArgumentParser(description = 'AWS WP Provisioner')
        

try:
    parser = Parser(target = argv[1], data = argv[2])

except:
    print('Usage: python3 ./parser.py <target> [terraform/ansible] <data>[the raw data in string format]')
    exit(1)

    