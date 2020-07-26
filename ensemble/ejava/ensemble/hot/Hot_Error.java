package ensemble.hot;

public class Hot_Error {
    private int val;
    private String msg;

    public Hot_Error(int value, String message) {
	val = value;
	msg = message;
    }

    public String toString() {
	return new String("Hot_Error: " + val + ": " + msg);
    }

}
