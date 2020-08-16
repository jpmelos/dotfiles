find . -name "*.py" -print0 | xargs -0 isort --profile black
find . -name "*.py" -print0 | xargs -0 black
find . -name "*.py" -print0 | xargs -0 flake8
