"""Production data-source transition: only Health Connect (Build 89)."""
from runpy import run_path
run_path('scripts/build89_remove_bluetooth.py', run_name='__main__')
