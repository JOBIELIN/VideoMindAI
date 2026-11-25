package com.example.server.service;

import com.example.server.dto.AnalysisResult;
import com.example.server.dto.VideoContext;
import org.springframework.stereotype.Service;

import java.util.Locale;
import java.util.List;
import java.util.stream.IntStream;

@Service
public class EvidenceVerificationService {

    public boolean timestampCovered(VideoContext context, AnalysisResult.Evidence evidence) {
        return context != null && evidence != null && context.segments().stream()
                .anyMatch(segment -> containsTimestamp(segment, evidence.timestampMs()));
    }

    public boolean supported(VideoContext context, AnalysisResult.Evidence evidence) {
        if (context == null || evidence == null || evidence.content().isBlank()) return false;
        String source = evidence.source().toUpperCase(Locale.ROOT);
        if (!source.contains("ASR") && !source.contains("OCR")) return false;

        return context.segments().stream()
                .filter(segment -> containsTimestamp(segment, evidence.timestampMs()))
                .map(segment -> sourceText(segment, source))
                .anyMatch(candidate -> textMatches(evidence.content(), candidate));
    }

    public boolean supportsClaim(VideoContext context,
                                 String claim,
                                 AnalysisResult.Evidence evidence) {
        return evidence != null
                && !normalize(claim).isEmpty()
                && normalize(claim).equals(normalize(evidence.claim()))
                && supported(context, evidence);
    }

    /** Structural facts only: matching source text does not prove a claim's meaning. */
    public List<EvidenceCheck> inspect(VideoContext context, AnalysisResult result) {
        if (result == null || result.evidence() == null) return List.of();
        return IntStream.range(0, result.evidence().size()).mapToObj(index -> {
            AnalysisResult.Evidence evidence = result.evidence().get(index);
            List<Integer> bound = IntStream.range(0, result.conclusions().size())
                    .filter(i -> evidence != null && !normalize(evidence.claim()).isEmpty()
                            && normalize(result.conclusions().get(i)).equals(normalize(evidence.claim())))
                    .boxed().toList();
            return new EvidenceCheck(index, bound, timestampCovered(context, evidence), supported(context, evidence));
        }).toList();
    }

    public record EvidenceCheck(int evidenceIndex, List<Integer> boundConclusionIndexes,
                                boolean timestampCovered, boolean sourceTextVerified) { }

    private boolean containsTimestamp(VideoContext.VideoSegment segment, long timestampMs) {
        return timestampMs >= segment.startMs() && timestampMs < segment.endMs();
    }

    private String sourceText(VideoContext.VideoSegment segment, String source) {
        if (source.contains("ASR") && source.contains("OCR")) {
            return segment.transcript() + " " + String.join(" ", segment.ocrTexts());
        }
        if (source.contains("ASR")) return segment.transcript();
        return String.join(" ", segment.ocrTexts());
    }

    private boolean textMatches(String evidence, String candidate) {
        String normalizedEvidence = normalize(evidence);
        String normalizedCandidate = normalize(candidate);
        return !normalizedEvidence.isEmpty()
                && !normalizedCandidate.isEmpty()
                && normalizedCandidate.contains(normalizedEvidence);
    }

    private String normalize(String value) {
        return value == null
                ? ""
                : value.toLowerCase(Locale.ROOT).replaceAll("[\\p{P}\\p{S}\\s]+", "");
    }
}
