#!/usr/bin/env python3
"""
Document Classification Utility
Intelligently determines document type from content using RAG queries.
"""

import re
import logging
from typing import Dict, Optional, List, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)

class DocumentClassifier:
    """Classifies insurance documents based on content analysis"""
    
    def __init__(self, rag_pipeline=None):
        self.rag_pipeline = rag_pipeline
        
        # Keywords for different insurance types
        self.type_keywords = {
            'health_insurance': [
                'health', 'medical', 'hospital', 'doctor', 'physician', 'clinic',
                'prescription', 'medication', 'surgery', 'treatment', 'diagnosis',
                'copay', 'deductible', 'premium', 'coverage', 'benefit', 'claim',
                'preventive care', 'emergency room', 'outpatient', 'inpatient',
                'mental health', 'dental', 'vision', 'pharmacy', 'specialist'
            ],
            'auto_insurance': [
                'auto', 'vehicle', 'car', 'truck', 'motorcycle', 'driving',
                'collision', 'comprehensive', 'liability', 'uninsured motorist',
                'bodily injury', 'property damage', 'personal injury protection',
                'medical payments', 'rental reimbursement', 'roadside assistance',
                'vin', 'license plate', 'registration', 'driver', 'accident'
            ],
            'home_insurance': [
                'home', 'house', 'property', 'dwelling', 'residence', 'homeowner',
                'fire', 'theft', 'burglary', 'vandalism', 'natural disaster',
                'flood', 'earthquake', 'hurricane', 'tornado', 'hail',
                'personal property', 'liability', 'guest medical', 'loss of use',
                'replacement cost', 'actual cash value', 'mortgage', 'lender'
            ],
            'life_insurance': [
                'life', 'death', 'beneficiary', 'term life', 'whole life',
                'universal life', 'variable life', 'permanent', 'temporary',
                'death benefit', 'cash value', 'premium', 'policy loan',
                'surrender value', 'rider', 'accidental death', 'disability',
                'waiver of premium', 'estate planning', 'inheritance'
            ]
        }
        
        # Company patterns for insurer detection
        self.insurer_patterns = {
            'Aetna': ['aetna'],
            'Anthem': ['anthem', 'blue cross blue shield'],
            'Blue Cross': ['blue cross', 'bcbs'],
            'Blue Shield': ['blue shield'],
            'Cigna': ['cigna'],
            'UnitedHealth': ['united health', 'unitedhealthcare', 'united healthcare'],
            'Humana': ['humana'],
            'Kaiser': ['kaiser permanente', 'kaiser'],
            'MetLife': ['metlife', 'met life'],
            'Prudential': ['prudential'],
            'State Farm': ['state farm'],
            'Allstate': ['allstate'],
            'Geico': ['geico'],
            'Progressive': ['progressive'],
            'Farmers': ['farmers insurance', 'farmers'],
            'Liberty Mutual': ['liberty mutual'],
            'Nationwide': ['nationwide'],
            'Travelers': ['travelers'],
            'USAA': ['usaa'],
            'New York Life': ['new york life', 'nyl'],
            'Northwestern Mutual': ['northwestern mutual'],
            'Niva Bupa': ['niva bupa', 'nivabupa'],
            'Bajaj Allianz': ['bajaj allianz', 'bajaj'],
            'HDFC ERGO': ['hdfc ergo', 'hdfc'],
            'ICICI Lombard': ['icici lombard', 'icici'],
            'Tata AIG': ['tata aig', 'tata'],
            'Reliance General': ['reliance general', 'reliance'],
            'SBI General': ['sbi general', 'sbi'],
            'Oriental Insurance': ['oriental insurance', 'oriental'],
            'National Insurance': ['national insurance'],
            'United India Insurance': ['united india insurance']
        }
    
    async def classify_document(self, document_id: str, text_content: str = None) -> Dict[str, any]:
        """
        Classify document type and extract metadata
        
        Args:
            document_id: Document identifier
            text_content: Optional text content (if not provided, will query RAG)
            
        Returns:
            Classification results with type, insurer, confidence, etc.
        """
        try:
            # If no text provided, try to get it from RAG
            if not text_content and self.rag_pipeline:
                # Query for document content
                query_result = await self._query_document_content(document_id)
                text_content = query_result.get('content', '')
            
            if not text_content:
                logger.warning(f"No text content available for document {document_id}")
                return self._default_classification()
            
            # Perform classification
            doc_type = self._classify_document_type(text_content)
            insurer = self._extract_insurer(text_content)
            policy_info = self._extract_policy_info(text_content)
            
            # Calculate confidence based on keyword matches
            confidence = self._calculate_confidence(text_content, doc_type)
            
            classification = {
                'document_type': doc_type,
                'insurer': insurer,
                'policy_number': policy_info.get('policy_number'),
                'effective_date': policy_info.get('effective_date'),
                'expiration_date': policy_info.get('expiration_date'),
                'confidence': confidence,
                'classified_at': datetime.utcnow().isoformat(),
                'method': 'content_analysis'
            }
            
            logger.info(f"Document {document_id} classified as {doc_type} with {confidence:.2f} confidence")
            return classification
            
        except Exception as e:
            logger.error(f"Classification failed for document {document_id}: {str(e)}")
            return self._default_classification()
    
    async def _query_document_content(self, document_id: str) -> Dict[str, any]:
        """Query RAG system for document content"""
        if not self.rag_pipeline:
            return {}
        
        try:
            # Query for general document content
            result = await self.rag_pipeline.query(
                "What type of insurance document is this? Provide details about the policy type, insurer, and key information.",
                filters={'document_id': document_id}
            )
            
            return {
                'content': result.get('answer', ''),
                'sources': result.get('sources', [])
            }
        except Exception as e:
            logger.error(f"Failed to query document content: {str(e)}")
            return {}
    
    def _classify_document_type(self, text: str) -> str:
        """Classify document type based on keyword analysis"""
        text_lower = text.lower()
        
        # Count keyword matches for each type
        type_scores = {}
        for doc_type, keywords in self.type_keywords.items():
            score = sum(1 for keyword in keywords if keyword in text_lower)
            type_scores[doc_type] = score
        
        # Find the type with highest score
        if type_scores:
            best_type = max(type_scores, key=type_scores.get)
            if type_scores[best_type] > 0:
                # Convert to display format
                return best_type.replace('_', ' ').title()
        
        # Fallback to generic
        return 'Insurance Policy'
    
    def _extract_insurer(self, text: str) -> str:
        """Extract insurance company name from text"""
        text_lower = text.lower()
        
        # Check for insurer patterns
        for insurer, patterns in self.insurer_patterns.items():
            for pattern in patterns:
                if pattern in text_lower:
                    return insurer
        
        # Try to extract from common patterns
        insurer_patterns = [
            r'(?:issued by|underwritten by|insurer:?)\s*([A-Z][A-Za-z\s&]+?)(?:\n|$|,)',
            r'([A-Z][A-Za-z\s&]+?)\s+(?:insurance|assurance)',
            r'policy issued by\s+([A-Z][A-Za-z\s&]+)',
        ]
        
        for pattern in insurer_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                insurer = match.group(1).strip()
                if len(insurer) > 3 and len(insurer) < 50:  # Reasonable length
                    return insurer
        
        return 'Unknown'
    
    def _extract_policy_info(self, text: str) -> Dict[str, Optional[str]]:
        """Extract policy number and dates from text"""
        policy_info = {
            'policy_number': None,
            'effective_date': None,
            'expiration_date': None
        }
        
        # Policy number patterns
        policy_patterns = [
            r'policy\s*(?:number|no\.?|#):?\s*([A-Z0-9\-]+)',
            r'policy\s*([A-Z0-9\-]{8,})',
            r'certificate\s*(?:number|no\.?):?\s*([A-Z0-9\-]+)',
        ]
        
        for pattern in policy_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                policy_info['policy_number'] = match.group(1)
                break
        
        # Date patterns
        date_patterns = [
            r'effective\s*(?:date|from):?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
            r'policy\s*period:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s*(?:to|through|-)\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
            r'coverage\s*period:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s*(?:to|through|-)\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        ]
        
        for pattern in date_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                if len(match.groups()) == 1:
                    policy_info['effective_date'] = match.group(1)
                elif len(match.groups()) == 2:
                    policy_info['effective_date'] = match.group(1)
                    policy_info['expiration_date'] = match.group(2)
                break
        
        return policy_info
    
    def _calculate_confidence(self, text: str, doc_type: str) -> float:
        """Calculate classification confidence based on keyword density"""
        text_lower = text.lower()
        text_length = len(text_lower.split())
        
        if text_length == 0:
            return 0.0
        
        # Get keywords for the classified type
        doc_type_key = doc_type.lower().replace(' ', '_')
        keywords = self.type_keywords.get(doc_type_key, [])
        
        if not keywords:
            return 0.5  # Default confidence for unknown types
        
        # Count keyword matches
        matches = sum(1 for keyword in keywords if keyword in text_lower)
        
        # Calculate confidence based on keyword density
        keyword_density = matches / len(keywords)
        text_density = min(matches / text_length * 100, 1.0)  # Cap at 1.0
        
        # Combine both metrics
        confidence = (keyword_density * 0.7) + (text_density * 0.3)
        
        return min(confidence, 1.0)
    
    def _default_classification(self) -> Dict[str, any]:
        """Return default classification when analysis fails"""
        return {
            'document_type': 'Insurance Policy',
            'insurer': 'Unknown',
            'policy_number': None,
            'effective_date': None,
            'expiration_date': None,
            'confidence': 0.0,
            'classified_at': datetime.utcnow().isoformat(),
            'method': 'default'
        }

# Global classifier instance
_classifier_instance = None

def get_document_classifier(rag_pipeline=None) -> DocumentClassifier:
    """Get or create document classifier instance"""
    global _classifier_instance
    if _classifier_instance is None:
        _classifier_instance = DocumentClassifier(rag_pipeline)
    elif rag_pipeline and not _classifier_instance.rag_pipeline:
        _classifier_instance.rag_pipeline = rag_pipeline
    return _classifier_instance 