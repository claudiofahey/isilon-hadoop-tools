#!/usr/bin/env python
import random
import sys
import string
import datetime
import multiprocessing
import os

def write_random_log_file(filename, num_lines=10):
	print('Writing file ' + filename)
	with open(filename, 'a') as log_file:
		for line_index in xrange(1,num_lines):
			line = datetime.datetime.utcnow().isoformat() + ': '
			for word_index in range(1, random.choice(range(3,16))):
				word = ''
				for letter_index in range(1, random.choice(range(2,11))):
					letter = random.choice(string.ascii_lowercase)
					word = word + letter
				line = line + word + ' '
			line = line + '\n'
			log_file.write(line)

def worker(config):
	write_random_log_file(config['filename'], num_lines=config['num_lines'])	
			
def main():
	log_dir = sys.argv[1]
	num_logs = int(sys.argv[2])
	num_lines = int(sys.argv[3])
	pool = multiprocessing.Pool(processes=num_logs)
	configs = map(lambda i: {
		'filename': os.path.join(log_dir, 'random%d.log'%i),
		'num_lines': num_lines
		}, range(0, num_logs))
	pool.map(worker, configs)
	
if __name__ == '__main__':
    main()
