import fileinput

files = {}
for line in fileinput.input():
  fields = line.split("\t")
  day = fields[-1].strip()
  f = files.get(day)
  if f is None:
    f = open("split/{}".format(day), "w")
    files[day] = f
  f.write(line)

for d, f in files.iteritems():
  f.close()
