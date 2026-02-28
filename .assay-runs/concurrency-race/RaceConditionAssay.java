import java.util.concurrent.atomic.AtomicInteger;

public class RaceConditionAssay {
    private static AtomicInteger counter = new AtomicInteger(0);
