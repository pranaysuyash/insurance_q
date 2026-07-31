class DemoService {
  Map<String, dynamic> buildLocalPolicyAnswer(String query,
      {String? documentId}) {
    final normalized = query.toLowerCase();
    const sources = [
      {'text': 'Policy Schedule (Policy Certificate)', 'page_number': 1}
    ];

    if (normalized.contains('policy number')) {
      return {
        'answer': 'Your policy number is 4214i/CPHSR/407834350/00/000.',
        'sources': sources,
      };
    }

    if (normalized.contains('start and end') ||
        normalized.contains('policy period') ||
        normalized.contains('policy start') ||
        normalized.contains('policy end') ||
        normalized.contains('when does my policy start')) {
      return {
        'answer': 'Your policy period is from 27-Aug-2025 to 26-Aug-2026.',
        'sources': sources,
      };
    }

    if (normalized.contains('insurer') ||
        normalized.contains('insurance company') ||
        normalized.contains('who provides coverage')) {
      return {
        'answer':
            'The insurer is ICICI Lombard General Insurance Company Limited.',
        'sources': sources,
      };
    }

    if (normalized.contains('insured parties') ||
        normalized.contains('policy holders') ||
        normalized.contains('insured individuals') ||
        normalized.contains('who are covered')) {
      return {
        'answer':
            'The insured individuals are Aarav Mehta, Priya Mehta, and Anika Mehta.',
        'sources': sources,
      };
    }

    if (normalized.contains('type of insurance')) {
      return {
        'answer': 'This is a Health Insurance policy.',
        'sources': sources,
      };
    }

    if (normalized.contains('total coverage') ||
        normalized.contains('sum insured') ||
        normalized.contains('coverage amount') ||
        normalized.contains('annual sum insured')) {
      return {
        'answer': 'The annual sum insured is ₹25,00,000.',
        'sources': sources,
      };
    }

    if (normalized.contains('premium')) {
      return {
        'answer': 'The total premium paid is ₹31,705 for this annual policy.',
        'sources': sources,
      };
    }

    if (normalized.contains('deductible')) {
      return {
        'answer': 'No deductible is listed in the extracted policy schedule.',
        'sources': sources,
      };
    }

    if (normalized.contains('room rent')) {
      return {
        'answer': 'There is no room rent capping listed in the policy.',
        'sources': sources,
      };
    }

    if (normalized.contains('hospital stays') ||
        normalized.contains('hospitalisation') ||
        normalized.contains('hospitalization')) {
      return {
        'answer':
            'In-patient treatment is covered up to the annual sum insured, with pre-hospitalisation expenses for 60 days and post-hospitalisation expenses for 180 days.',
        'sources': sources,
      };
    }

    if (normalized.contains('maternity')) {
      return {
        'answer':
            'For a ₹25,00,000 sum insured, the maternity limit is ₹40,000, and the plan covers both normal and C-section deliveries for up to 2 events.',
        'sources': sources,
      };
    }

    if (normalized.contains('day care')) {
      return {
        'answer':
            'Daycare procedures are covered up to the annual sum insured.',
        'sources': sources,
      };
    }

    if (normalized.contains('claims process') ||
        normalized.contains('how do i file a claim') ||
        normalized.contains('file a claim') ||
        normalized.contains('claim')) {
      return {
        'answer':
            'Cashless claims can be raised through network hospitals, and reimbursement/claim support is available via the policy helpline at 1800 2666 and ihealthcare@icicilombard.com.',
        'sources': sources,
      };
    }

    if (normalized.contains('exclusions') ||
        normalized.contains('what is not covered') ||
        normalized.contains('pre-existing condition') ||
        normalized.contains('waiting period')) {
      return {
        'answer':
            'The schedule highlights pre-existing illness/injury/symptom exclusions subject to policy terms and conditions; the extracted schedule does not list a single universal waiting-period number.',
        'sources': sources,
      };
    }

    if (normalized.contains('dental') ||
        normalized.contains('vision') ||
        normalized.contains('mental health') ||
        normalized.contains('prescription drugs')) {
      return {
        'answer':
            'This benefit is not clearly listed in the extracted policy schedule, so I would treat it as not confirmed from the policy text I reviewed.',
        'sources': sources,
      };
    }

    return {
      'answer':
          'I found the policy, but I need a more specific question to answer accurately from the extracted schedule.',
      'sources': sources,
    };
  }
}
