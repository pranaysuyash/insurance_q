"""
policy_rag_hybrid.py   –   Health-insurance QA (generic, GPT-4-class)

Run:
    streamlit run policy_rag_hybrid.py

Flow:
    • Upload one or more policy PDFs.
    • Ask a free-form question, e.g. "since when am I with Niva Bupa".
"""

import os, re, json, hashlib, time
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import List, Tuple, Dict, Any, Optional, Union
from datetime import datetime

import streamlit as st
from dotenv import load_dotenv
import pdfplumber
import pytesseract
from pdf2image import convert_from_path
from pypdf import PdfReader
import pandas as pd

from langchain_community.document_loaders import Py